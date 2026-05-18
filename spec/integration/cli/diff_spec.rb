require "spec_helper"
require "json"
require "taskmate/cli/commands/diff"
require "taskmate/workspace/issue_file"

RSpec.describe Taskmate::CLI::Commands::Diff do
  let(:workspace) { create_temp_workspace(initialized: true) }

  # Writes issue and returns its re-serialized raw_content (via IssueFile)
  # so the synced copy can be written with exactly matching bytes.
  def write_current_issue
    path = write_file(workspace, "issues/TEST-1.md", <<~MD)
      ---
      key: TEST-1
      summary: Test issue
      issue_type: Task
      status: To Do
      priority: Medium
      labels:
        - backend
      sync_state: clean
      jira_source_hash: sha256:aaaa
      last_synced_local_hash: sha256:aaaa
      ---

      Current body
    MD
    Taskmate::Workspace::IssueFile.read(path).raw_content
  end

  def write_synced_copy(content)
    write_file(workspace, "issues/.jira/TEST-1.synced.md", content)
  end

  def write_synced_copy_with_old_content
    write_file(workspace, "issues/.jira/TEST-1.synced.md", <<~MD)
      ---
      key: TEST-1
      summary: Test issue
      issue_type: Task
      status: To Do
      priority: Medium
      labels:
        - backend
      sync_state: clean
      jira_source_hash: sha256:aaaa
      last_synced_local_hash: sha256:aaaa
      ---

      Old body
    MD
  end

  describe "#call" do
    context "with default text output" do
      subject(:command) { described_class.new(format: "text") }

      it "prints no changes when synced copy matches" do
        raw = write_current_issue
        write_synced_copy(raw)

        expect { command.call("TEST-1", workspace) }
          .to output("No changes in TEST-1\n").to_stdout
      end

      it "prints diff header and diff body when changes exist" do
        write_current_issue
        write_synced_copy_with_old_content

        output = capture_stdout { command.call("TEST-1", workspace) }

        expect(output).to include("Diff for TEST-1 (vs last pull):")
        expect(output).to include("Current body")
      end
    end

    context "with json output" do
      subject(:command) { described_class.new(format: "json") }

      it "prints empty diff as json when synced copy matches" do
        raw = write_current_issue
        write_synced_copy(raw)

        data = JSON.parse(capture_stdout { command.call("TEST-1", workspace) })

        expect(data["issue_key"]).to eq("TEST-1")
        expect(data["empty"]).to be(true)
        expect(data["hunks"]).to eq([])
      end

      it "prints non-empty diff as json when changes exist" do
        write_current_issue
        write_synced_copy_with_old_content

        data = JSON.parse(capture_stdout { command.call("TEST-1", workspace) })

        expect(data["issue_key"]).to eq("TEST-1")
        expect(data["empty"]).to be(false)
        expect(data["hunks"]).not_to be_empty
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
