require "spec_helper"
require "taskmate/core/diff_issue"
require "taskmate/workspace/issue_file"
require "taskmate/workspace/diff"

RSpec.describe Taskmate::Core::DiffIssue do
  subject(:service) { described_class.new(workspace_path: tmpdir) }

  let(:tmpdir) { Dir.mktmpdir }
  let(:issues_dir) { File.join(tmpdir, "issues").tap { |d| FileUtils.mkdir_p(d) } }

  after { FileUtils.rm_rf(tmpdir) }

  def write_issue_file(key, body: "Body\n")
    content = "---\nkey: #{key}\nsummary: Summary\nissue_type: Task\n---\n#{body}"
    path = File.join(issues_dir, "#{key}.md")
    File.write(path, content)
    path
  end

  describe "#call" do
    it "returns a Workspace::Diff object" do
      write_issue_file("SAR-1")
      result = service.call("SAR-1")
      expect(result).to be_a(Taskmate::Workspace::Diff)
    end

    it "diff carries the issue key" do
      write_issue_file("SAR-1")
      result = service.call("SAR-1")
      expect(result.issue_key).to eq("SAR-1")
    end

    it "diff is non-empty when no synced copy exists" do
      write_issue_file("SAR-1")
      result = service.call("SAR-1")
      expect(result.empty?).to be(false)
    end

    it "diff is empty when synced copy matches current file" do
      path = write_issue_file("SAR-1")
      content = File.read(path)
      jira_dir = File.join(issues_dir, ".jira")
      FileUtils.mkdir_p(jira_dir)
      File.write(File.join(jira_dir, "SAR-1.synced.md"), content)
      result = service.call("SAR-1")
      expect(result.empty?).to be(true)
    end

    it "raises IssueNotFoundError when file is absent" do
      expect { service.call("SAR-404") }
        .to raise_error(Taskmate::IssueNotFoundError, /SAR-404/)
    end
  end
end
