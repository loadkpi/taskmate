require "spec_helper"
require "taskmate/security/policy"
require "taskmate/security/consent_manager"
require "taskmate/workspace/issue_file"
require "taskmate/workspace/ignore_rules"

RSpec.describe Taskmate::Security::Policy do
  let(:workspace) { create_temp_workspace(initialized: true) }

  def build_issue(body:, key: "SAR-1", path: nil)
    fm = { "key" => key, "summary" => "Test", "issue_type" => "Task" }
    Taskmate::Workspace::IssueFile.build(frontmatter: fm, body: body, path: path)
  end

  describe "#authorize_ai_call" do
    context "with safe content and FakeConsentManager(:allow)" do
      let(:policy) do
        described_class.new(
          workspace_path:  workspace,
          consent_manager: Taskmate::Security::FakeConsentManager.new(response: :allow)
        )
      end

      it "returns :allow" do
        issue = build_issue(body: "Normal bug description.")
        expect(policy.authorize_ai_call(issue_file: issue, provider: "openai")).to eq(:allow)
      end
    end

    context "with safe content and FakeConsentManager(:deny)" do
      let(:policy) do
        described_class.new(
          workspace_path:  workspace,
          consent_manager: Taskmate::Security::FakeConsentManager.new(response: :deny)
        )
      end

      it "returns :deny when consent is denied" do
        issue = build_issue(body: "Normal description.")
        expect(policy.authorize_ai_call(issue_file: issue, provider: "openai")).to eq(:deny)
      end
    end

    context "when secrets are detected" do
      let(:policy) do
        described_class.new(
          workspace_path:  workspace,
          consent_manager: Taskmate::Security::FakeConsentManager.new(response: :allow)
        )
      end

      it "blocks before consent — returns :deny" do
        issue = build_issue(body: "Key: AKIAIOSFODNN7EXAMPLE hardcoded here.")
        expect(policy.authorize_ai_call(issue_file: issue, provider: "openai")).to eq(:deny)
      end
    end

    context "when issue is in excluded path" do
      let(:policy) do
        described_class.new(
          workspace_path:  workspace,
          consent_manager: Taskmate::Security::FakeConsentManager.new(response: :allow)
        )
      end

      it "returns :deny for ignored file even if consent would allow" do
        File.write(File.join(workspace, ".taskmateignore"), "issues/private/\n")
        issue_path = File.join(workspace, "issues", "private", "SAR-1.md")
        FileUtils.mkdir_p(File.dirname(issue_path))
        issue = build_issue(body: "Secret project info.", path: issue_path)
        result = policy.authorize_ai_call(issue_file: issue, provider: "openai")
        expect(result).to eq(:deny)
      end
    end
  end

  describe "#authorize_jira_write" do
    let(:plan) do
      change = Taskmate::Security::ActionGate::FieldChange.new(
        field: "status", from: "Open", to: "Done"
      )
      Taskmate::Security::ActionGate::ActionPlan.build(field_changes: [change])
    end

    it "returns :allow when action gate allows" do
      gate   = instance_double(Taskmate::Security::ActionGate, confirm: :allow)
      policy = described_class.new(workspace_path: workspace, action_gate: gate)
      expect(policy.authorize_jira_write(plan)).to eq(:allow)
    end

    it "returns :deny when action gate denies" do
      gate   = instance_double(Taskmate::Security::ActionGate, confirm: :deny)
      policy = described_class.new(workspace_path: workspace, action_gate: gate)
      expect(policy.authorize_jira_write(plan)).to eq(:deny)
    end
  end
end
