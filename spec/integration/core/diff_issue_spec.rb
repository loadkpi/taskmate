require "spec_helper"
require "taskmate/core/diff_issue"
require "taskmate/workspace/issue_file"

RSpec.describe Taskmate::Core::DiffIssue do
  subject(:service) { described_class.new(workspace_path: workspace) }

  let(:workspace) { create_temp_workspace(initialized: true) }

  def write_issue(key, body: "Body\n")
    fm = { "key" => key, "summary" => "Issue #{key}", "issue_type" => "Task" }
    issue = Taskmate::Workspace::IssueFile.build(frontmatter: fm, body: body)
    path = File.join(workspace, "issues", "#{key}.md")
    issue.write(path)
    issue
  end

  describe "#call" do
    context "when the issue file exists" do
      before { write_issue("SAR-10") }

      it "returns a Workspace::Diff object" do
        result = service.call("SAR-10")
        expect(result).to be_a(Taskmate::Workspace::Diff)
      end

      it "reports issue_key on the diff" do
        result = service.call("SAR-10")
        expect(result.issue_key).to eq("SAR-10")
      end

      it "diff is non-empty when no synced copy exists" do
        result = service.call("SAR-10")
        expect(result.empty?).to be(false)
      end

      it "diff is empty when synced copy matches current content" do
        path = File.join(workspace, "issues", "SAR-10.md")
        content = File.read(path)
        jira_dir = File.join(workspace, "issues", ".jira")
        FileUtils.mkdir_p(jira_dir)
        File.write(File.join(jira_dir, "SAR-10.synced.md"), content)
        result = service.call("SAR-10")
        expect(result.empty?).to be(true)
      end
    end

    context "when the issue file does not exist" do
      it "raises IssueNotFoundError" do
        expect { service.call("SAR-404") }
          .to raise_error(Taskmate::IssueNotFoundError, /SAR-404/)
      end
    end
  end
end
