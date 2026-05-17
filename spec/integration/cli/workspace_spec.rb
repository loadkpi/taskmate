require "spec_helper"
require "json"
require "taskmate/cli/commands/workspace"
require "taskmate/workspace/issue_file"
require "taskmate/workspace/canonical_hash"

RSpec.describe Taskmate::CLI::Commands::Workspace do
  let(:workspace) { create_temp_workspace(initialized: true) }

  def write_clean_issue(key:, summary:)
    issue = Taskmate::Workspace::IssueFile.build(
      frontmatter: {
        "key" => key,
        "summary" => summary,
        "issue_type" => "Task",
        "status" => "To Do",
        "priority" => "Medium"
      },
      body: "Body\n"
    )

    path = File.join(workspace, "issues", "#{key}.md")
    issue.write(path)

    issue.last_synced_local_hash = Taskmate::Workspace::CanonicalHash.compute_for(issue)
    issue.jira_source_hash = "sha256:source"
    issue.sync_state = "clean"
    issue.write

    issue
  end

  def write_local_changed_issue(key:, summary:)
    issue = write_clean_issue(key: key, summary: summary)
    issue.body = "Modified body\n"
    issue.write
    issue
  end

  def write_new_local_issue(summary:)
    write_file(workspace, "issues/new/new-task.md", <<~MD)
      ---
      key:
      summary: #{summary}
      issue_type: Task
      status: To Do
      priority: Medium
      ---

      Draft body
    MD
  end

  def write_conflict_file(filename:)
    write_file(workspace, "issues/conflicts/#{filename}", "conflict content\n")
  end

  describe "#status" do
    context "with text output" do
      subject(:command) { described_class.new(format: "text") }

      it "prints empty workspace message when no issues exist" do
        output = capture_stdout { command.status(workspace) }

        expect(output).to eq("Workspace is empty — no issues found.\n")
      end

      it "prints local_changed, new_local, and clean sections" do
        write_local_changed_issue(key: "TEST-1", summary: "Changed issue")
        write_new_local_issue(summary: "Draft task")
        write_clean_issue(key: "TEST-2", summary: "Clean issue")

        output = capture_stdout { command.status(workspace) }

        expect(output).to include("Local changes (1):")
        expect(output).to include("M TEST-1")
        expect(output).to include("Changed issue")
        expect(output).to include("New local (1):")
        expect(output).to include("(new)")
        expect(output).to include("Draft task")
        expect(output).to include("Clean (1):")
        expect(output).to include("TEST-2")
        expect(output).to include("Clean issue")
      end

      it "prints unresolved conflict files section when conflicts exist" do
        write_conflict_file(filename: "TEST-3.jira.20250101.md")

        output = capture_stdout { command.status(workspace) }

        expect(output).to include("Unresolved conflict files (1):")
        expect(output).to include("! TEST-3.jira.20250101.md")
      end
    end

    context "with json output" do
      subject(:command) { described_class.new(format: "json") }

      it "prints workspace status as json with all sections" do
        write_local_changed_issue(key: "TEST-1", summary: "Changed issue")
        write_new_local_issue(summary: "Draft task")
        write_clean_issue(key: "TEST-2", summary: "Clean issue")
        write_conflict_file(filename: "TEST-3.jira.20250101.md")

        data = JSON.parse(capture_stdout { command.status(workspace) })

        expect(data["local_changed"]).to include(
          { "key" => "TEST-1", "summary" => "Changed issue" }
        )
        expect(data["new_local"]).to include(
          { "key" => nil, "summary" => "Draft task" }
        )
        expect(data["clean"]).to include(
          { "key" => "TEST-2", "summary" => "Clean issue" }
        )
        expect(data["conflict_files"]).to eq(["TEST-3.jira.20250101.md"])
      end
    end

    context "with invalid format" do
      subject(:command) { described_class.new(format: "yaml") }

      it "raises ValidationError" do
        expect { command.status(workspace) }
          .to raise_error(Taskmate::ValidationError, /Invalid format/)
      end
    end
  end
end
