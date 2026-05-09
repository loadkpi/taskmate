require "spec_helper"
require "taskmate/core/show_issue"
require "taskmate/workspace/issue_file"

RSpec.describe Taskmate::Core::ShowIssue do
  subject(:service) { described_class.new(workspace_path: workspace) }

  let(:workspace) { create_temp_workspace(initialized: true) }

  def write_issue(key, summary: "Test Issue", body: "Body text\n")
    fm = { "key" => key, "summary" => summary, "issue_type" => "Task",
           "status" => "Open", "priority" => "Medium", "labels" => [] }
    issue = Taskmate::Workspace::IssueFile.build(frontmatter: fm, body: body)
    path = File.join(workspace, "issues", "#{key}.md")
    issue.write(path)
    issue
  end

  describe "#call" do
    context "when the issue file exists" do
      before { write_issue("SAR-42", summary: "Do the thing") }

      it "returns a ShowResult with the issue_file" do
        result = service.call("SAR-42")
        expect(result.issue_file).to be_a(Taskmate::Workspace::IssueFile)
        expect(result.issue_file.key).to eq("SAR-42")
        expect(result.issue_file.summary).to eq("Do the thing")
      end

      it "defaults format to :text" do
        result = service.call("SAR-42")
        expect(result.format).to eq(:text)
      end

      it "passes through a custom format" do
        result = service.call("SAR-42", format: :json)
        expect(result.format).to eq(:json)
      end
    end

    context "when the issue file does not exist" do
      it "raises IssueNotFoundError" do
        expect { service.call("SAR-999") }
          .to raise_error(Taskmate::IssueNotFoundError, /SAR-999/)
      end
    end
  end
end
