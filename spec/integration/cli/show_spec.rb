require "spec_helper"
require "json"
require "taskmate/cli/commands/show"

RSpec.describe Taskmate::CLI::Commands::Show do
  let(:workspace) { create_temp_workspace(initialized: true) }

  def write_issue_with_assignee
    write_file(workspace, "issues/TEST-1.md", <<~MD)
      ---
      key: TEST-1
      summary: Test issue
      issue_type: Task
      status: To Do
      priority: Medium
      labels:
        - backend
        - cli
      sync_state: clean
      jira_source_hash: sha256:aaaa
      last_synced_local_hash: sha256:aaaa
      assignee:
        account_id: acc-123
        display_name: Jane Doe
        email: jane@example.com
      ---

      Issue body
    MD
  end

  def write_issue_without_assignee_or_labels
    write_file(workspace, "issues/TEST-2.md", <<~MD)
      ---
      key: TEST-2
      summary: Unassigned issue
      issue_type: Bug
      status: In Progress
      priority: High
      labels: []
      sync_state: clean
      jira_source_hash: sha256:bbbb
      last_synced_local_hash: sha256:bbbb
      ---

      Another body
    MD
  end

  describe "#call" do
    context "with default text output" do
      subject(:command) { described_class.new(format: "text") }

      it "prints issue details in text format" do
        write_issue_with_assignee

        output = capture_stdout { command.call("TEST-1", workspace) }

        expect(output).to include("TEST-1  Test issue")
        expect(output).to include("Status: To Do  Priority: Medium  Type: Task")
        expect(output).to include("Assignee: Jane Doe")
        expect(output).to include("Labels: backend, cli")
        expect(output).to include("Issue body")
      end

      it "prints unassigned and omits labels line when labels are empty" do
        write_issue_without_assignee_or_labels

        output = capture_stdout { command.call("TEST-2", workspace) }

        expect(output).to include("TEST-2  Unassigned issue")
        expect(output).to include("Status: In Progress  Priority: High  Type: Bug")
        expect(output).to include("Assignee: (unassigned)")
        expect(output).not_to include("Labels:")
        expect(output).to include("Another body")
      end
    end

    context "with metadata enabled" do
      subject(:command) { described_class.new(format: "text", metadata: true) }

      it "prints metadata section in text format" do
        write_issue_with_assignee

        output = capture_stdout { command.call("TEST-1", workspace) }

        expect(output).to include("--- Metadata ---")
        expect(output).to include("sync_state: clean")
        expect(output).to include("jira_source_hash: sha256:aaaa")
        expect(output).to include("last_synced_local_hash: sha256:aaaa")
      end
    end

    context "with json output" do
      subject(:command) { described_class.new(format: "json") }

      it "prints issue details as json" do
        write_issue_with_assignee

        data = JSON.parse(capture_stdout { command.call("TEST-1", workspace) })

        expect(data).to eq(
          {
            "key" => "TEST-1",
            "summary" => "Test issue",
            "status" => "To Do",
            "priority" => "Medium",
            "assignee" => {
              "account_id" => "acc-123",
              "display_name" => "Jane Doe",
              "email" => "jane@example.com"
            },
            "labels" => %w[backend cli],
            "body" => "\nIssue body\n"
          }
        )
      end
    end

    context "with json output and metadata enabled" do
      subject(:command) { described_class.new(format: "json", metadata: true) }

      it "prints frontmatter fields plus body and serialized assignee" do
        write_issue_with_assignee

        data = JSON.parse(capture_stdout { command.call("TEST-1", workspace) })

        expect(data).to include(
          "key" => "TEST-1",
          "summary" => "Test issue",
          "issue_type" => "Task",
          "status" => "To Do",
          "priority" => "Medium",
          "labels" => %w[backend cli],
          "sync_state" => "clean",
          "jira_source_hash" => "sha256:aaaa",
          "last_synced_local_hash" => "sha256:aaaa",
          "body" => "\nIssue body\n",
          "assignee" => {
            "account_id" => "acc-123",
            "display_name" => "Jane Doe",
            "email" => "jane@example.com"
          }
        )
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
