require "spec_helper"
require "taskmate/workspace/issue_file"

RSpec.describe Taskmate::Workspace::IssueFile do
  let(:workspace) { create_temp_workspace(initialized: true) }

  let(:frontmatter) do
    {
      "key" => "SAR-123",
      "summary" => "Fix login bug",
      "issue_type" => "Bug",
      "priority" => "High",
      "labels" => %w[backend auth],
      "assignee" => { "account_id" => "u1", "display_name" => "Alice", "email" => "a@example.com" }
    }
  end
  let(:body) { "## Description\n\nUsers cannot log in.\n" }

  describe ".build" do
    it "creates an IssueFile with string-keyed frontmatter" do
      issue = described_class.build(frontmatter: frontmatter, body: body)
      expect(issue.key).to eq("SAR-123")
    end

    it "normalizes top-level symbol keys to strings" do
      sym_fm = { key: "SAR-1", summary: "Test" }
      issue = described_class.build(frontmatter: sym_fm, body: "")
      expect(issue.key).to eq("SAR-1")
      expect(issue.summary).to eq("Test")
    end

    it "normalizes symbol keys inside an array of hashes" do
      sym_fm = { key: "SAR-1", custom_field: [{ label_id: "b1", name: "backend" }] }
      issue = described_class.build(frontmatter: sym_fm, body: "")
      expect(issue.frontmatter["custom_field"].first).to eq({ "label_id" => "b1", "name" => "backend" })
    end

    it "normalizes nested symbol keys (e.g. assignee)" do
      sym_fm = { key: "SAR-1", assignee: { account_id: "u1", display_name: "Alice", email: "a@x.com" } }
      issue = described_class.build(frontmatter: sym_fm, body: "")
      expect(issue.assignee.display_name).to eq("Alice")
      expect(issue.assignee.account_id).to eq("u1")
    end
  end

  describe ".read" do
    it "reads a file and returns IssueFile" do
      path = File.join(workspace, "issues", "SAR-123.md")
      issue = described_class.build(frontmatter: frontmatter, body: body)
      issue.write(path)

      loaded = described_class.read(path)
      expect(loaded.key).to eq("SAR-123")
      expect(loaded.summary).to eq("Fix login bug")
      expect(loaded.body).to include("Users cannot log in")
    end

    it "raises IssueNotFoundError for missing file" do
      expect { described_class.read("/nonexistent/path.md") }
        .to raise_error(Taskmate::IssueNotFoundError)
    end
  end

  describe "#write" do
    it "writes file and can be re-read" do
      path = File.join(workspace, "issues", "SAR-123.md")
      issue = described_class.build(frontmatter: frontmatter, body: body)
      issue.write(path)

      expect(File.exist?(path)).to be(true)
      loaded = described_class.read(path)
      expect(loaded.key).to eq("SAR-123")
    end

    it "raises ArgumentError when no path set" do
      issue = described_class.build(frontmatter: frontmatter, body: body)
      expect { issue.write }.to raise_error(ArgumentError)
    end
  end

  describe "#new_local?" do
    it "returns true when key is nil" do
      issue = described_class.build(frontmatter: { "summary" => "New task" }, body: "")
      expect(issue.new_local?).to be(true)
    end

    it "returns false when key present" do
      issue = described_class.build(frontmatter: frontmatter, body: body)
      expect(issue.new_local?).to be(false)
    end
  end

  describe "#assignee" do
    it "returns StructuredUser with display_name" do
      issue = described_class.build(frontmatter: frontmatter, body: body)
      expect(issue.assignee.display_name).to eq("Alice")
      expect(issue.assignee.account_id).to eq("u1")
    end

    it "returns nil when no assignee" do
      issue = described_class.build(frontmatter: { "key" => "SAR-1" }, body: "")
      expect(issue.assignee).to be_nil
    end
  end

  describe "#default_path" do
    it "returns issues/<KEY>.md for existing issues" do
      issue = described_class.build(frontmatter: frontmatter, body: body)
      expect(issue.default_path(workspace)).to end_with("issues/SAR-123.md")
    end

    it "returns issues/new/<date>-<slug>.md for new local" do
      issue = described_class.build(frontmatter: { "summary" => "Add auth feature" }, body: "")
      path = issue.default_path(workspace)
      expect(path).to match(%r{issues/new/\d{4}-\d{2}-\d{2}-add-auth-feature\.md})
    end
  end

  describe "#project" do
    it "extracts project from key" do
      issue = described_class.build(frontmatter: frontmatter, body: body)
      expect(issue.project).to eq("SAR")
    end

    it "returns nil for new local issue" do
      issue = described_class.build(frontmatter: { "summary" => "x" }, body: "")
      expect(issue.project).to be_nil
    end
  end
end
