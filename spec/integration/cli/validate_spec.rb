require "spec_helper"
require "json"
require "taskmate/cli/commands/validate"

RSpec.describe Taskmate::CLI::Commands::Validate do
  let(:workspace) { create_temp_workspace(initialized: true) }

  def write_valid_issue
    write_file(workspace, "issues/TEST-1.md", <<~MD)
      ---
      key: TEST-1
      summary: Valid issue
      issue_type: Task
      status: To Do
      priority: Medium
      sync_state: clean
      jira_source_hash: sha256:aaaa
      last_synced_local_hash: sha256:aaaa
      ---

      Normal paragraph.

      - list item
    MD
  end

  def write_invalid_issue
    write_file(workspace, "issues/BROKEN-1.md", <<~MD)
      ---
      key: BROKEN-1
      summary: Broken issue
      issue_type: Task
      status: To Do
      priority: Medium
      sync_state: clean
      jira_source_hash: sha256:bbbb
      last_synced_local_hash: sha256:bbbb
      ---

      > Blockquote is not supported

      ~~strikethrough~~ is not supported
    MD
  end

  describe "#call" do
    context "with text output" do
      subject(:command) { described_class.new(format: "text") }

      it "prints valid status for a valid issue" do
        write_valid_issue

        output = capture_stdout { command.call("TEST-1", workspace) }

        expect(output).to eq("TEST-1: valid\n")
      end

      it "prints validation errors for an invalid issue" do
        write_invalid_issue

        output, = capture_stdout_and_system_exit { command.call("BROKEN-1", workspace) }

        expect(output).to include("BROKEN-1: 2 error(s)")
        expect(output).to include("blockquote")
        expect(output).to include("strikethrough")
      end

      it "exits with status 2 for an invalid issue" do
        write_invalid_issue

        _, exit_error = capture_stdout_and_system_exit { command.call("BROKEN-1", workspace) }

        expect(exit_error).to be_a(SystemExit)
        expect(exit_error.status).to eq(2)
      end
    end

    context "with json output" do
      subject(:command) { described_class.new(format: "json") }

      it "prints valid result as json" do
        write_valid_issue

        data = JSON.parse(capture_stdout { command.call("TEST-1", workspace) })

        expect(data).to eq(
          {
            "key" => "TEST-1",
            "valid" => true,
            "errors" => []
          }
        )
      end

      it "prints invalid result as json with errors" do
        write_invalid_issue

        output, = capture_stdout_and_system_exit { command.call("BROKEN-1", workspace) }
        data = JSON.parse(output)

        expect(data["key"]).to eq("BROKEN-1")
        expect(data["valid"]).to eq(false)
        expect(data["errors"]).not_to be_empty
        expect(data["errors"].map { |e| e["feature"] }).to include("blockquote", "strikethrough")
      end

      it "exits with status 2 for an invalid issue" do
        write_invalid_issue

        _, exit_error = capture_stdout_and_system_exit { command.call("BROKEN-1", workspace) }

        expect(exit_error).to be_a(SystemExit)
        expect(exit_error.status).to eq(2)
      end
    end

    context "with invalid format" do
      subject(:command) { described_class.new(format: "yaml") }

      it "raises ValidationError" do
        expect { command.call("TEST-1", workspace) }
          .to raise_error(Taskmate::ValidationError, /Invalid format/)
      end
    end

    context "when issue does not exist" do
      subject(:command) { described_class.new(format: "text") }

      it "raises IssueNotFoundError" do
        expect { command.call("MISSING-1", workspace) }
          .to raise_error(Taskmate::IssueNotFoundError, /MISSING-1/)
      end
    end
  end
end
