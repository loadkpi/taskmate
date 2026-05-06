require "spec_helper"
require "taskmate/core/show_issue"
require "taskmate/workspace/issue_file"

RSpec.describe Taskmate::Core::ShowIssue do
  let(:tmpdir) { Dir.mktmpdir }
  let(:issues_dir) { File.join(tmpdir, "issues").tap { |d| FileUtils.mkdir_p(d) } }

  after { FileUtils.rm_rf(tmpdir) }

  def write_issue_file(key)
    content = "---\nkey: #{key}\nsummary: Summary\nissue_type: Task\n---\nBody\n"
    path = File.join(issues_dir, "#{key}.md")
    File.write(path, content)
    path
  end

  subject(:service) { described_class.new(workspace_path: tmpdir) }

  describe "#call" do
    it "returns a ShowResult struct" do
      write_issue_file("SAR-1")
      result = service.call("SAR-1")
      expect(result).to respond_to(:issue_file)
      expect(result).to respond_to(:format)
    end

    it "returns the parsed issue_file" do
      write_issue_file("SAR-1")
      result = service.call("SAR-1")
      expect(result.issue_file.key).to eq("SAR-1")
    end

    it "defaults format to :text" do
      write_issue_file("SAR-1")
      result = service.call("SAR-1")
      expect(result.format).to eq(:text)
    end

    it "honors a custom format" do
      write_issue_file("SAR-1")
      result = service.call("SAR-1", format: :json)
      expect(result.format).to eq(:json)
    end

    it "raises IssueNotFoundError when file is absent" do
      expect { service.call("SAR-999") }
        .to raise_error(Taskmate::IssueNotFoundError, /SAR-999/)
    end

    it "error message mentions pull command" do
      expect { service.call("SAR-999") }
        .to raise_error(Taskmate::IssueNotFoundError, /pull/)
    end
  end
end
