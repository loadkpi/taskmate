require "spec_helper"
require "taskmate/core/workspace_status"
require "taskmate/workspace/issue_file"
require "taskmate/workspace/canonical_hash"

RSpec.describe Taskmate::Core::WorkspaceStatus do
  let(:workspace) { create_temp_workspace(initialized: true) }
  subject(:service) { described_class.new(workspace_path: workspace) }

  def write_issue(key, extra_fm = {}, body: "Body\n")
    fm = { "key" => key, "summary" => "Issue #{key}", "issue_type" => "Task" }.merge(extra_fm)
    issue = Taskmate::Workspace::IssueFile.build(frontmatter: fm, body: body)
    path  = File.join(workspace, "issues", "#{key}.md")
    issue.write(path)
    issue
  end

  def write_clean_issue(key)
    issue = write_issue(key)
    h = Taskmate::Workspace::CanonicalHash.compute_for(issue)
    issue.last_synced_local_hash = h
    issue.write
    issue
  end

  describe "#call" do
    it "returns empty status for empty workspace" do
      result = service.call
      expect(result.clean).to be_empty
      expect(result.local_changed).to be_empty
      expect(result.new_local).to be_empty
      expect(result.conflict_files).to be_empty
    end

    it "shows clean issue in clean list" do
      write_clean_issue("SAR-1")
      result = service.call
      expect(result.clean.map(&:key)).to include("SAR-1")
    end

    it "shows locally modified issue in local_changed" do
      issue = write_clean_issue("SAR-2")
      # Modify body after syncing
      issue.body = "Modified\n"
      issue.write
      result = service.call
      expect(result.local_changed.map(&:key)).to include("SAR-2")
    end

    it "shows new local issue in new_local" do
      fm = { "key" => nil, "summary" => "New task" }
      issue = Taskmate::Workspace::IssueFile.build(frontmatter: fm, body: "Draft\n")
      issue.write(File.join(workspace, "issues", "new", "new-task.md"))
      result = service.call
      expect(result.new_local.any? { |i| i.summary == "New task" }).to be(true)
    end

    it "shows conflict files" do
      File.write(File.join(workspace, "issues", "conflicts", "SAR-3.jira.20250101.md"), "conflict")
      result = service.call
      expect(result.conflict_files).not_to be_empty
    end

    it "classifies a keyed file under issues/new/ by sync state" do
      issue = write_clean_issue("SAR-99")
      # move to issues/new/ (unusual but shouldn't be silently lost)
      new_path = File.join(workspace, "issues", "new", "SAR-99.md")
      FileUtils.mv(File.join(workspace, "issues", "SAR-99.md"), new_path)
      issue.path = new_path
      result = service.call
      # Should appear in clean (not silently dropped)
      expect(result.clean.map(&:key)).to include("SAR-99")
    end

    it "does not fail on files with invalid frontmatter" do
      File.write(File.join(workspace, "issues", "bad.md"), "no frontmatter here")
      expect { service.call }.not_to raise_error
    end
  end
end
