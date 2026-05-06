require "spec_helper"
require "taskmate/workspace/sync_state"
require "taskmate/workspace/issue_file"
require "taskmate/workspace/canonical_hash"

RSpec.describe Taskmate::Workspace::SyncState do
  def build_issue(key: "SAR-1", body: "Body\n", last_hash: nil)
    fm = {
      "key" => key,
      "summary" => "Test",
      "issue_type" => "Task",
      "last_synced_local_hash" => last_hash
    }
    Taskmate::Workspace::IssueFile.build(frontmatter: fm, body: body)
  end

  def current_hash(issue)
    Taskmate::Workspace::CanonicalHash.compute_for(issue)
  end

  describe ".compute" do
    context "when key is nil" do
      it "returns :new_local" do
        issue = build_issue(key: nil)
        expect(described_class.compute(issue_file: issue)).to eq(:new_local)
      end
    end

    context "when unchanged local, no jira_hash" do
      it "returns :clean" do
        issue = build_issue
        issue.last_synced_local_hash = current_hash(issue)
        expect(described_class.compute(issue_file: issue)).to eq(:clean)
      end
    end

    context "when unchanged local, jira_hash matches stored" do
      it "returns :clean" do
        issue = build_issue
        h = current_hash(issue)
        issue.last_synced_local_hash = h
        issue.frontmatter["jira_source_hash"] = "sha256:abc"
        expect(described_class.compute(issue_file: issue, jira_hash: "sha256:abc")).to eq(:clean)
      end
    end

    context "when body changed locally" do
      it "returns :local_changed" do
        issue = build_issue
        issue.last_synced_local_hash = current_hash(issue)
        issue.body = "Changed body\n"
        expect(described_class.compute(issue_file: issue)).to eq(:local_changed)
      end
    end

    context "when jira changed but local unchanged" do
      it "returns :jira_changed" do
        issue = build_issue
        h = current_hash(issue)
        issue.last_synced_local_hash = h
        issue.frontmatter["jira_source_hash"] = "sha256:original"
        expect(described_class.compute(issue_file: issue, jira_hash: "sha256:new")).to eq(:jira_changed)
      end
    end

    context "when both local and jira changed" do
      it "returns :conflict" do
        issue = build_issue
        issue.last_synced_local_hash = current_hash(issue)
        issue.frontmatter["jira_source_hash"] = "sha256:original"
        issue.body = "Changed locally\n"
        expect(described_class.compute(issue_file: issue, jira_hash: "sha256:new")).to eq(:conflict)
      end
    end
  end
end
