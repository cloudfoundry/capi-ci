# frozen_string_literal: true

require 'rspec'
require_relative 'release_notes'

RSpec.describe ReleaseNotes do
  context 'when parsing the git log' do
    let(:git_log) do
      <<~EOS
        ari-wg-gitbot@@@app-runtime-interfaces@cloudfoundry.org@@@Create final release 1.123.0@@@@@@@@@
        ari-wg-gitbot@@@app-runtime-interfaces@cloudfoundry.org@@@Bump cloud_controller_ng, code.cloudfoundry.org/some-lib@@@Changes in cloud_controller_ng:

        - Allow users to do fancy stuff with the API
            PR: cloudfoundry/cloud_controller_ng#1234
            Author: Mary Smith <m.smith@example.com>

        - Fix a nasty bug
            PR: cloudfoundry/cloud_controller_ng#2345
            Author: James Johnson <j.johnson@example.com>
            Author: Patricia Williams <p.williams@example.com>

        Dependency updates in cloud_controller_ng:

        - build(deps): bump some-gem from 1.2.3 to 2.3.4
            PR: cloudfoundry/cloud_controller_ng#3456
            Author: dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>

        Dependency updates in code.cloudfoundry.org/some-lib:

        - Bump code.cloudfoundry.org/other-lib from 3.4.5 to 4.5.6
            PR: cloudfoundry/some-lib#4567
            Author: dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>@@@@@@
        John Brown@@@j.brown@example.com@@@Add parameter to enable new feature (#5678)@@@
        Co-authored-by: Linda Jones <l.jones@example.com>@@@@@@
        dependabot[bot]@@@49699333+dependabot[bot]@users.noreply.github.com@@@Build(deps-dev): Bump some-gem from 5.6.7 to 6.7.8 in /spec (#6789)@@@@@@@@@
        ari-wg-gitbot@@@app-runtime-interfaces@cloudfoundry.org@@@Bump something to 7.8.9@@@@@@@@@
        ari-wg-gitbot@@@app-runtime-interfaces@cloudfoundry.org@@@Bump cloud_controller_ng@@@@@@@@@
      EOS
    end

    subject(:items) { ReleaseNotes.parse_git_log(git_log) }

    it 'returns the items' do
      expect(items.count).to eq(7)
      expect(items[0]).to eq({
                               subproject: 'cloud_controller_ng',
                               dependency_update: false,
                               message: 'Allow users to do fancy stuff with the API',
                               pr_link: 'cloudfoundry/cloud_controller_ng#1234',
                               authors: [
                                 'Mary Smith <m.smith@example.com>'
                               ]
                             })
      expect(items[1]).to eq({
                               subproject: 'cloud_controller_ng',
                               dependency_update: false,
                               message: 'Fix a nasty bug',
                               pr_link: 'cloudfoundry/cloud_controller_ng#2345',
                               authors: [
                                 'James Johnson <j.johnson@example.com>',
                                 'Patricia Williams <p.williams@example.com>'
                               ]
                             })
      expect(items[2]).to eq({
                               subproject: 'cloud_controller_ng',
                               dependency_update: true,
                               message: 'build(deps): bump some-gem from 1.2.3 to 2.3.4',
                               pr_link: 'cloudfoundry/cloud_controller_ng#3456',
                               authors: [
                                 'dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>'
                               ]
                             })
      expect(items[3]).to eq({
                               subproject: 'code.cloudfoundry.org/some-lib',
                               dependency_update: true,
                               message: 'Bump code.cloudfoundry.org/other-lib from 3.4.5 to 4.5.6',
                               pr_link: 'cloudfoundry/some-lib#4567',
                               authors: [
                                 'dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>'
                               ]
                             })
      expect(items[4]).to eq({
                               subproject: nil,
                               dependency_update: false,
                               message: 'Add parameter to enable new feature',
                               pr_link: 'cloudfoundry/capi-release#5678',
                               authors: [
                                 'John Brown <j.brown@example.com>',
                                 'Linda Jones <l.jones@example.com>'
                               ]
                             })
      expect(items[5]).to eq({
                               subproject: nil,
                               dependency_update: true,
                               message: 'Build(deps-dev): Bump some-gem from 5.6.7 to 6.7.8 in /spec',
                               pr_link: 'cloudfoundry/capi-release#6789',
                               authors: [
                                 'dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>'
                               ]
                             })
      expect(items[6]).to eq({
                               subproject: nil,
                               dependency_update: true,
                               message: 'Bump something to 7.8.9',
                               pr_link: nil,
                               authors: [
                                 'ari-wg-gitbot <app-runtime-interfaces@cloudfoundry.org>'
                               ]
                             })
    end
  end

  context 'when detecting database migrations' do
    let(:old_sha) { 'aabbcc1111111111111111111111111111111111' }
    let(:new_sha) { 'ddeeff2222222222222222222222222222222222' }

    let(:submodule_diff) do
      <<~DIFF
        diff --git a/src/cloud_controller_ng b/src/cloud_controller_ng
        index #{old_sha[0..9]}..#{new_sha[0..9]} 160000
        --- a/src/cloud_controller_ng
        +++ b/src/cloud_controller_ng
        @@ -1 +1 @@
        -Subproject commit #{old_sha}
        +Subproject commit #{new_sha}
      DIFF
    end

    describe '.get_ccng_shas' do
      it 'extracts old and new SHAs from submodule diff' do
        allow(ReleaseNotes).to receive(:`).and_return(submodule_diff)
        expect(ReleaseNotes.get_ccng_shas('1.231.0', '1.232.0')).to eq([old_sha, new_sha])
      end

      it 'returns nil SHAs when there is no submodule diff' do
        allow(ReleaseNotes).to receive(:`).and_return('')
        expect(ReleaseNotes.get_ccng_shas('1.231.0', '1.232.0')).to eq([nil, nil])
      end
    end

    describe '.get_new_migration_files' do
      it 'returns migration filenames added between the two SHAs' do
        migration_diff = "db/migrations/20260318083940_add_unique_constraint_to_buildpacks.rb\n" \
                         "db/migrations/20260320141005_add_unique_constraint_to_revision_sidecars.rb\n"
        allow(ReleaseNotes).to receive(:`).and_return(migration_diff)
        expect(ReleaseNotes.get_new_migration_files('/path/to/ccng', old_sha, new_sha)).to eq(
          ['20260318083940_add_unique_constraint_to_buildpacks.rb',
           '20260320141005_add_unique_constraint_to_revision_sidecars.rb']
        )
      end

      it 'returns an empty array when there are no new migrations' do
        allow(ReleaseNotes).to receive(:`).and_return('')
        expect(ReleaseNotes.get_new_migration_files('/path/to/ccng', old_sha, new_sha)).to eq([])
      end

      it 'returns an empty array when SHAs are nil' do
        expect(ReleaseNotes.get_new_migration_files('/path/to/ccng', nil, nil)).to eq([])
      end
    end

    describe '.print_db_migrations' do
      it 'prints migration links when migrations exist' do
        migration_filename = '20260318083940_add_unique_constraint_to_buildpacks.rb'
        allow(ReleaseNotes).to receive(:get_ccng_shas).and_return([old_sha, new_sha])
        allow(ReleaseNotes).to receive(:get_new_migration_files).and_return([migration_filename])

        expected_output = "\n### Cloud Controller Database Migrations\n" \
          "- [#{migration_filename}](https://github.com/cloudfoundry/cloud_controller_ng/blob/#{new_sha}/db/migrations/#{migration_filename})\n"
        expect { ReleaseNotes.print_db_migrations('/path/to/ccng', '1.231.0', '1.232.0') }
          .to output(expected_output).to_stdout
      end

      it 'prints None when there are no migrations' do
        allow(ReleaseNotes).to receive(:get_ccng_shas).and_return([old_sha, new_sha])
        allow(ReleaseNotes).to receive(:get_new_migration_files).and_return([])

        expect { ReleaseNotes.print_db_migrations('/path/to/ccng', '1.231.0', '1.232.0') }
          .to output("\n### Cloud Controller Database Migrations\nNone\n").to_stdout
      end
    end
  end
end
