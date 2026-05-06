require "spec_helper"
require "taskmate/workspace/issue_file"
require "taskmate/core/show_issue"
require "taskmate/core/validate_issue"
require "taskmate/workspace/diff"
require "taskmate/core/workspace_status"

# Offline commands: work without any network stubs
RSpec.describe "Offline commands", type: :integration do
  let(:workspace) { create_temp_workspace(initialized: true) }

  let(:issue_content) do
    <<~MD
      ---
      key: OFFLINE-1
      summary: Offline test issue
      issue_type: Task
      status: To Do
      priority: Medium
      labels:
        - test
      sync_state: clean
      jira_source_hash: sha256:aaaa
      last_synced_local_hash: sha256:aaaa
      ---

      ## Description

      This issue is for testing offline commands.

      ## Notes

      - Requires no network connection
    MD
  end

  before do
    FileUtils.mkdir_p(File.join(workspace, "issues"))
    File.write(File.join(workspace, "issues", "OFFLINE-1.md"), issue_content)
  end

  describe "show" do
    it "displays issue details without network" do
      result = Taskmate::Core::ShowIssue.new(workspace_path: workspace).call("OFFLINE-1")
      expect(result.issue_file.key).to eq("OFFLINE-1")
      expect(result.issue_file.summary).to eq("Offline test issue")
    end
  end

  describe "validate" do
    it "validates Markdown without network" do
      result = Taskmate::Core::ValidateIssue.new(workspace_path: workspace).call("OFFLINE-1")
      expect(result.valid?).to be true
      expect(result.errors).to be_empty
    end

    it "detects unsupported features without network" do
      write_file(workspace, "issues/BROKEN-1.md", <<~MD)
        ---
        key: BROKEN-1
        summary: Broken issue
        sync_state: clean
        jira_source_hash: sha256:bbbb
        last_synced_local_hash: sha256:bbbb
        ---

        Normal text.

        > This blockquote is not supported.

        ~~strikethrough~~ not allowed either.
      MD
      result = Taskmate::Core::ValidateIssue.new(workspace_path: workspace).call("BROKEN-1")
      expect(result.valid?).to be false
      features = result.errors.map(&:feature)
      expect(features).to include("blockquote")
      expect(features).to include("strikethrough")
    end
  end

  describe "workspace status" do
    it "shows status without network" do
      result = Taskmate::Core::WorkspaceStatus.new(workspace_path: workspace).call
      all_issues = result.clean + result.local_changed + result.new_local
      keys = all_issues.map(&:key)
      expect(keys).to include("OFFLINE-1")
    end
  end

  describe "diff" do
    it "computes diff for an issue without network" do
      issue_path = File.join(workspace, "issues", "OFFLINE-1.md")
      issue_file = Taskmate::Workspace::IssueFile.read(issue_path)

      diff = Taskmate::Workspace::Diff.compute(issue_file)
      # No synced copy exists → diff shows all lines as additions (not empty)
      expect(diff).not_to be_nil
      expect(diff.hunks).not_to be_empty
    end

    it "shows no changes when synced copy matches" do
      issue_path  = File.join(workspace, "issues", "OFFLINE-1.md")
      synced_path = File.join(workspace, "issues", ".jira", "OFFLINE-1.synced.md")
      FileUtils.mkdir_p(File.dirname(synced_path))

      # Write identical synced copy
      File.write(synced_path, File.read(issue_path))

      issue_file = Taskmate::Workspace::IssueFile.read(issue_path)
      diff = Taskmate::Workspace::Diff.compute(issue_file)
      expect(diff.empty?).to be true
    end
  end
end
