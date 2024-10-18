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
end
