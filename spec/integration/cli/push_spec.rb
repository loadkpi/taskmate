require "spec_helper"
require "json"
require "taskmate/jira/client"
require "taskmate/security/policy"
require "taskmate/core/pull_issue"
require "taskmate/cli/commands/push"
require "taskmate/config"

RSpec.describe Taskmate::CLI::Commands::Push do
  let(:workspace) { create_temp_workspace(initialized: true) }

  let(:fake_client) do
    FakeJiraClient.new(issues: {
                         "TEST-1" => { "summary" => "Original summary" }
                       })
  end

  let(:fake_policy) do
    instance_double(Taskmate::Security::Policy).tap do |p|
      allow(p).to receive(:authorize_jira_write).and_return(:allow)
      allow(p).to receive(:write_action_audit).and_return(nil)
    end
  end

  let(:fake_config) do
    Taskmate::Config::AppConfig.new(
      tracker: Taskmate::Config::TrackerConfig.new(
        base_url: "https://fake.atlassian.net", default_project: "", story_points_field: nil
      ),
      auth: Taskmate::Config::JiraAuthConfig.new(email: "user@example.com", api_token: "token"),
      ai: Taskmate::Config::AiConfig.new(provider: "disabled", model: nil, enabled: true),
      security: Taskmate::Config::SecurityConfig.new(
        require_consent_for_ai: true, require_confirm_for_push: true, secret_detection: true
      ),
      push: Taskmate::Config::PushConfig.new(allowed_fields: %w[summary description labels components priority])
    )
  end

  def pull_issue
    Taskmate::Core::PullIssue.new(
      workspace_path: workspace,
      jira_client: fake_client
    ).call("TEST-1")
  end

  def write_clean_issue
    pull_issue
  end

  def write_modified_issue
    pull_issue
    path = File.join(workspace, "issues", "TEST-1.md")
    content = File.read(path)
    File.write(path, content.sub("summary: Original summary", "summary: Updated summary"))
  end

  before do
    allow(Taskmate::Config::Loader).to receive(:load).and_return(fake_config)
    allow(Taskmate::Jira::Client).to receive(:new).and_return(fake_client)
    allow(Taskmate::Security::Policy).to receive(:new).and_return(fake_policy)
  end

  describe "#call" do
    context "with dry_run text output" do
      subject(:command) { described_class.new(format: "text", dry_run: true) }

      it "prints DRY RUN header" do
        write_clean_issue
        output = capture_stdout { command.call("TEST-1", workspace) }
        expect(output).to include("[DRY RUN]")
        expect(output).to include("TEST-1")
      end
    end

    context "when applied with text output" do
      subject(:command) { described_class.new(format: "text") }

      it "prints push success message" do
        write_modified_issue
        output = capture_stdout { command.call("TEST-1", workspace) }
        expect(output).to include("Pushed TEST-1 to Jira")
      end
    end

    context "with json output" do
      subject(:command) { described_class.new(format: "json") }

      it "returns key, applied and dry_run fields" do
        write_modified_issue
        data = JSON.parse(capture_stdout { command.call("TEST-1", workspace) })
        expect(data["key"]).to eq("TEST-1")
        expect(data).to have_key("applied")
        expect(data).to have_key("dry_run")
      end
    end

    context "with invalid format" do
      subject(:command) { described_class.new(format: "yaml") }

      it "raises ValidationError" do
        expect { command.call("TEST-1", workspace) }
          .to raise_error(Taskmate::ValidationError, /Invalid format/)
      end
    end

    context "when workspace.yml is missing" do
      subject(:command) { described_class.new(format: "text") }

      before { allow(Taskmate::Config::Loader).to receive(:load).and_call_original }

      it "raises ConfigError" do
        empty_workspace = create_temp_workspace
        expect { command.call("TEST-1", empty_workspace) }
          .to raise_error(Taskmate::ConfigError, /workspace\.yml not found/)
      end
    end
  end
end
