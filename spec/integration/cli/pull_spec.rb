require "spec_helper"
require "json"
require "taskmate/jira/client"
require "taskmate/cli/commands/pull"
require "taskmate/config"

RSpec.describe Taskmate::CLI::Commands::Pull do
  let(:workspace) { create_temp_workspace(initialized: true) }

  let(:fake_client) do
    FakeJiraClient.new(issues: {
                         "TEST-1" => { "summary" => "Pull test issue" }
                       })
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
      push: Taskmate::Config::PushConfig.new(allowed_fields: %w[summary description])
    )
  end

  before do
    allow(Taskmate::Config::Loader).to receive(:load).and_return(fake_config)
    allow(Taskmate::Jira::Client).to receive(:new).and_return(fake_client)
  end

  describe "#call (single issue)" do
    context "with text output" do
      subject(:command) { described_class.new(format: "text") }

      it "prints success message with key and path" do
        output = capture_stdout { command.call("TEST-1", workspace) }
        expect(output).to include("Pulled TEST-1")
        expect(output).to include(".md")
      end
    end

    context "with json output" do
      subject(:command) { described_class.new(format: "json") }

      it "returns key and path as json" do
        data = JSON.parse(capture_stdout { command.call("TEST-1", workspace) })
        expect(data["key"]).to eq("TEST-1")
        expect(data["path"]).to include("TEST-1.md")
      end

      it "includes unsupported_nodes field" do
        data = JSON.parse(capture_stdout { command.call("TEST-1", workspace) })
        expect(data).to have_key("unsupported_nodes")
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

    context "when issue does not exist" do
      subject(:command) { described_class.new(format: "text") }

      it "raises IssueNotFoundError" do
        expect { command.call("MISSING-99", workspace) }
          .to raise_error(Taskmate::IssueNotFoundError)
      end
    end
  end

  describe "#call (JQL batch)" do
    let(:batch_client) do
      FakeJiraClient.new(issues: {
                           "TEST-1" => { "summary" => "First" },
                           "TEST-2" => { "summary" => "Second" }
                         })
    end

    before { allow(Taskmate::Jira::Client).to receive(:new).and_return(batch_client) }

    context "with text output" do
      subject(:command) { described_class.new(format: "text", jql: "project = TEST", limit: 50) }

      it "prints pulled count" do
        output = capture_stdout { command.call(nil, workspace) }
        expect(output).to include("Pulled 2/2 issues")
      end
    end

    context "with json output" do
      subject(:command) { described_class.new(format: "json", jql: "project = TEST", limit: 50) }

      it "returns total, pulled array and failed array" do
        data = JSON.parse(capture_stdout { command.call(nil, workspace) })
        expect(data["total"]).to eq(2)
        expect(data["pulled"].size).to eq(2)
        expect(data["failed"]).to eq([])
      end
    end
  end
end
