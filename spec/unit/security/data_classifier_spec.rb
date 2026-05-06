require "spec_helper"
require "taskmate/security/data_classifier"
require "taskmate/workspace/issue_file"
require "taskmate/workspace/ignore_rules"

RSpec.describe Taskmate::Security::DataClassifier do
  let(:tmpdir) { Dir.mktmpdir }
  after { FileUtils.rm_rf(tmpdir) }

  def build_issue(body:, key: "SAR-1", summary: "Test issue", path: nil)
    fm = { "key" => key, "summary" => summary, "issue_type" => "Task" }
    issue = Taskmate::Workspace::IssueFile.build(frontmatter: fm, body: body, path: path)
    issue
  end

  let(:ignore_rules) { Taskmate::Workspace::IgnoreRules.new("") }
  subject(:classifier) { described_class.new(workspace_path: tmpdir, ignore_rules: ignore_rules) }

  describe "#classify" do
    context "with ordinary issue body" do
      it "returns :safe classification" do
        issue = build_issue(body: "Fix the login button alignment on mobile.")
        result = classifier.classify(issue)
        expect(result.level).to eq(:safe)
      end

      it "has sections in result" do
        issue = build_issue(body: "Normal description.")
        result = classifier.classify(issue)
        expect(result.sections).not_to be_empty
      end

      it "has empty excluded_paths" do
        issue = build_issue(body: "Normal description.")
        result = classifier.classify(issue)
        expect(result.excluded_paths).to be_empty
      end
    end

    context "with secret in body" do
      it "returns :secret classification" do
        issue = build_issue(body: "Token: AKIAIOSFODNN7EXAMPLE is hardcoded here.")
        result = classifier.classify(issue)
        expect(result.level).to eq(:secret)
      end

      it "body section has :secret level" do
        issue = build_issue(body: "gh_token = ghp_16C7e42F292c6912E7710c838347Ae178B4a")
        result = classifier.classify(issue)
        body_section = result.sections.find { |s| s.name == "body" }
        expect(body_section.level).to eq(:secret)
      end
    end

    context "with sensitive words in body" do
      it "returns :sensitive for body containing 'password' mention" do
        issue = build_issue(body: "The password field should be masked in the UI.")
        result = classifier.classify(issue)
        expect(result.level).to eq(:sensitive)
      end
    end

    context "with ignored file" do
      it "returns :excluded when path matches .taskmateignore" do
        rules = Taskmate::Workspace::IgnoreRules.new("private/\n")
        c = described_class.new(workspace_path: tmpdir, ignore_rules: rules)
        issue_path = File.join(tmpdir, "issues", "private", "SAR-1.md")
        issue = build_issue(body: "Secret stuff", path: issue_path)
        result = c.classify(issue)
        expect(result.level).to eq(:excluded)
      end

      it "excluded result has no sections" do
        rules = Taskmate::Workspace::IgnoreRules.new("private/\n")
        c = described_class.new(workspace_path: tmpdir, ignore_rules: rules)
        issue_path = File.join(tmpdir, "issues", "private", "SAR-1.md")
        issue = build_issue(body: "Secret stuff", path: issue_path)
        result = c.classify(issue)
        expect(result.sections).to be_empty
      end

      it "excluded result lists the excluded path" do
        rules = Taskmate::Workspace::IgnoreRules.new("private/\n")
        c = described_class.new(workspace_path: tmpdir, ignore_rules: rules)
        issue_path = File.join(tmpdir, "issues", "private", "SAR-1.md")
        issue = build_issue(body: "Secret stuff", path: issue_path)
        result = c.classify(issue)
        expect(result.excluded_paths).not_to be_empty
      end
    end
  end
end
