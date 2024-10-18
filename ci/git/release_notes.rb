#!/usr/bin/env ruby
# frozen_string_literal: true

require 'cgi/util'
require 'net/http'
require 'json'
require 'set'

module ReleaseNotes
  def self.execute_git_log_command(previous_version, version)
    `git log #{previous_version}...#{version} --pretty=format:'%an@@@%ae@@@%s@@@%b@@@@@@' | grep -v 'gpg'`
      .force_encoding('UTF-8')
  end

  def self.parse_submodule_update_commit(body)
    items = []
    item = nil
    body.each_line do |line|
      changes_in = line.match(/^Changes in (.+):/)
      dependency_updates_in = line.match(/^Dependency updates in (.+):/)

      if changes_in || dependency_updates_in
        items << item.dup if item && item[:message]

        item = {
          subproject: changes_in ? changes_in[1] : dependency_updates_in[1],
          dependency_update: changes_in ? false : true
        }
        next
      end

      next unless item

      line.match(/^- (.*)/) do |match|
        items << item.dup if item[:message]

        item.merge!({
                      message: match[1],
                      pr_link: nil,
                      authors: []
                    })
        next
      end

      next unless item[:message]

      line.match(/\s+PR: (.*)/) do |match|
        item[:pr_link] = match[1]
        next
      end

      line.match(/\s+Author: (.*)/) do |match|
        item[:authors] << match[1]
        next
      end
    end
    items << item.dup if item && item[:message]

    items
  end

  def self.parse_commit(author_name, author_email, message, body)
    # Don't include commits in the release notes that are only about creating the final release or
    # bumping the API versions (i.e. empty 'Bump cloud_controller_ng' commit)
    return [] if message.match?(/^(Create final release.*)|(Bump cloud_controller_ng)/)

    items = []
    pr_link = nil
    message = message.gsub(/\s*\(#(\d+)\)$/) do
      pr_link = "cloudfoundry/capi-release##{::Regexp.last_match(1)}"
      ''
    end

    authors = {}
    authors[author_email] = author_name
    /Co-authored-by:\s*(?<name>.+?)\s*<(?<email>.+?)>/m.match(body) do |match|
      authors[match[:email]] = match[:name]
    end

    items << {
      subproject: nil,
      dependency_update: message.match?(/[Bb]ump.*to/),
      message: message,
      pr_link: pr_link,
      authors: authors.map { |e, n| "#{n} <#{e}>" }
    }

    items
  end

  def self.parse_single_log(single_log)
    author_name, author_email, message, body = single_log.split('@@@', 4)

    items = []
    items += parse_submodule_update_commit(body) if message.match?(/^Bump/)
    items += parse_commit(author_name, author_email, message, body) if items.empty? # i.e. commit on capi-release

    items
  end

  def self.parse_git_log(git_log)
    items = []
    git_log.split("@@@@@@\n").each do |single_log|
      items += parse_single_log(single_log)
    end

    items
  end

  def self.get_github_user(author_email)
    email_escaped = CGI.escape(author_email)
    queries = []
    # Find email as author or committer in cloud_controller_ng or capi-release repository
    %w[cloud_controller_ng capi-release].each do |repo|
      %w[author committer].each do |role|
        queries << "https://api.github.com/repos/cloudfoundry/#{repo}/commits?#{role}=#{email_escaped}&per_page=1"
      end
    end

    queries.each do |query|
      Net::HTTP.start('api.github.com', 443, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(query)
        request['Accept'] = 'application/vnd.github+json'
        response = http.request(request)
        if response.code == '200'
          data = JSON.parse(response.body)
          return data[0]['author']['login'] if data && data[0]
        end
        sleep(3)
      end
    end
  end

  def self.print_item(item, github_users)
    item_str = "- #{item[:message]}"
    item_str += " (#{item[:pr_link]})" if item[:pr_link]

    author_str = ''
    item[:authors].each do |author|
      author.match(/(.*) <(.*)>/) do |match|
        author_name = match[1]
        author_email = match[2]
        github_users[author_email] = get_github_user(author_email) unless github_users[author_email]
        author_str += ', ' unless author_str.empty?
        author_str += github_users[author_email] ? "@#{github_users[author_email]}" : author_name
      end
    end
    item_str += " #{author_str}" unless author_str.empty?
    puts item_str
  end

  def self.print_release_notes(items)
    github_users = {}

    # Print release notes in the following order: CAPI Release, Cloud Controller, other subprojects
    subprojects = [nil, 'cloud_controller_ng'] + (items.map { |item|
      item[:subproject]
    }.compact.uniq - ['cloud_controller_ng']).sort
    subprojects.each do |subproject|
      puts "\n"
      case subproject
      when nil
        puts '### CAPI Release'
      when 'cloud_controller_ng'
        puts '### Cloud Controller'
      else
        puts "### #{subproject}"
      end

      # Print changes
      changes = items.select { |item| item[:subproject] == subproject && !item[:dependency_update] }
      changes.each { |item| print_item(item, github_users) }

      # Print dependency updates
      dependency_updates = items.select { |item| item[:subproject] == subproject && item[:dependency_update] }
      next if dependency_updates.empty?

      puts '#### Dependency Updates'
      bumps = {
        docs_dev: Set.new,
        docs_deps: Set.new,
        dev: Set.new,
        deps: Set.new,
        other: Set.new
      }
      dependency_updates.each do |item|
        case item[:message]
        when %r{[Bb]uild\(deps-dev\):.*in /docs/v3}
          bumps[:docs_dev] << item
        when %r{[Bb]uild\(deps\):.*in /docs/v3}
          bumps[:docs_deps] << item
        when /[Bb]uild\(deps-dev\):/
          bumps[:dev] << item
        when /[Bb]uild\(deps\):/
          bumps[:deps] << item
        else
          bumps[:other] << item
        end
      end

      %i[other deps dev docs_deps docs_dev].each do |type|
        bumps[type].each { |item| print_item(item, github_users) }
      end
    end
  end

  def self.run
    args = ARGV

    git_log = if args.length == 1
                # Test mode, i.e. read given git-log txt file
                File.read(args[0])
              else
                raise 'release_notes.rb <previous version> <version>' if args.length != 2

                execute_git_log_command(args[0], args[1])
              end
    items = parse_git_log(git_log)
    print_release_notes(items)
  end
end

ReleaseNotes.run if __FILE__ == $PROGRAM_NAME
