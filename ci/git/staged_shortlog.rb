#!/usr/bin/env ruby

def print(commit, subproject)
  # If the commit message ends with a PR number, add a newline and the PR link.
  message = commit[:message].gsub(/\s*\(#(\d+)\)$/) { "\n    PR: cloudfoundry/#{subproject}##{$1}" }
  puts "\n- #{message}"
  commit[:authors].each do |email, name|
    puts "    Author: #{name} <#{email}>"
  end
end

diffs = `git diff --cached`.split('diff --git').select { |log| log =~ /Subproject/ }

subprojects = {}
diffs.each do |diff|
  /a\/(?<loc>.+?)\sb.*index\s(?<shas>\S+)/m.match(diff) do |matches|
    subprojects[matches[:loc].gsub(/^src\//, '')] = { loc: matches[:loc], shas: matches[:shas] }
  end
end

puts "Bump #{subprojects.keys.join(", ")}"

subprojects.each do |subproject, diff|
  commits = []

  Dir.chdir(diff[:loc]) do
    `git log #{diff[:shas]} --pretty=format:'%an@@@%ae@@@%s@@@%b@@@@@@' | grep -v 'gpg'`.force_encoding('UTF-8').split("@@@@@@\n").each do |log|
      author_name, author_email, message, body = log.split("@@@", 4)
      authors = {}
      authors[author_email] = author_name
      /Co-authored-by:\s*(?<name>.+?)\s*<(?<email>.+?)>/m.match(body) do |matches|
        authors[matches[:email]] = matches[:name]
      end

      # Skip commits where the only author is the ari-wg-gitbot.
      next if authors.count == 1 && (author_email == 'app-runtime-interfaces@cloudfoundry.org' || author_name == 'ari-wg-gitbot')

      commits << { message: message, authors: authors, dependency_update: message =~ /[Bb]ump.*from.*to/ }
    end
  end

  changes = commits.select { |c| !c[:dependency_update] }
  dependency_updates = commits.select { |c| c[:dependency_update] }

  if changes.any?
    puts "\nChanges in #{subproject}:"
    changes.each { |c| print(c, subproject) }
  end

  if dependency_updates.any?
    puts "\nDependency updates in #{subproject}:"
    dependency_updates.each { |c| print(c, subproject) }
  end
end
