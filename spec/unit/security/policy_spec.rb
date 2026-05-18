require "spec_helper"
require "taskmate/security/policy"
require "taskmate/config"

RSpec.describe Taskmate::Security::Policy do
  let(:workspace) { create_temp_workspace(initialized: true) }

  def security_config(require_consent_for_ai: true, require_confirm_for_push: true, secret_detection: true)
    Taskmate::Config::SecurityConfig.new(
      require_consent_for_ai: require_consent_for_ai,
      require_confirm_for_push: require_confirm_for_push,
      secret_detection: secret_detection
    )
  end

  def issue_double(body: "Normal body text", path: nil)
    double("issue_file",
           body: body,
           path: path || File.join(workspace, "issues", "TEST-1.md"),
           frontmatter: {})
  end

  describe "#authorize_jira_write" do
    let(:action_plan) { Taskmate::Security::ActionGate::ActionPlan.build }

    context "when require_confirm_for_push is true" do
      let(:policy) do
        described_class.new(
          workspace_path: workspace,
          security_config: security_config(require_confirm_for_push: true),
          non_interactive: true
        )
      end

      it "delegates to action_gate (non_interactive → deny)" do
        expect(policy.authorize_jira_write(action_plan)).to eq(:deny)
      end
    end

    context "when require_confirm_for_push is false" do
      let(:policy) do
        described_class.new(
          workspace_path: workspace,
          security_config: security_config(require_confirm_for_push: false)
        )
      end

      it "auto-allows without prompting" do
        expect(policy.authorize_jira_write(action_plan)).to eq(:allow)
      end
    end
  end

  describe "#authorize_ai_call" do
    let(:provider) { "openai" }

    context "when require_consent_for_ai is false" do
      let(:policy) do
        described_class.new(
          workspace_path: workspace,
          security_config: security_config(require_consent_for_ai: false)
        )
      end

      it "auto-allows without consent prompt" do
        result = policy.authorize_ai_call(issue_file: issue_double, provider: provider)
        expect(result).to eq(:allow)
      end
    end

    context "when require_consent_for_ai is true and non_interactive" do
      let(:policy) do
        described_class.new(
          workspace_path: workspace,
          security_config: security_config(require_consent_for_ai: true),
          non_interactive: true
        )
      end

      it "denies (consent required but no prompt available)" do
        result = policy.authorize_ai_call(issue_file: issue_double, provider: provider)
        expect(result).to eq(:deny)
      end
    end

    context "when secret_detection is true and content has secrets" do
      let(:policy) do
        described_class.new(
          workspace_path: workspace,
          # require_consent_for_ai: false so the only deny path is secret detection
          security_config: security_config(secret_detection: true, require_consent_for_ai: false)
        )
      end

      it "blocks the call" do
        secret_issue = issue_double(body: "password: super_secret_token_abc123xyz")
        result = policy.authorize_ai_call(issue_file: secret_issue, provider: provider)
        expect(result).to eq(:deny)
      end
    end

    context "when secret_detection is false and content has secrets" do
      let(:policy) do
        described_class.new(
          workspace_path: workspace,
          security_config: security_config(secret_detection: false, require_consent_for_ai: false)
        )
      end

      it "does not block on detected secrets" do
        secret_issue = issue_double(body: "password: super_secret_token_abc123xyz")
        result = policy.authorize_ai_call(issue_file: secret_issue, provider: provider)
        expect(result).to eq(:allow)
      end
    end
  end

  describe "NULL_SECURITY_CONFIG default" do
    let(:policy) { described_class.new(workspace_path: workspace, non_interactive: true) }

    it "defaults to requiring push confirmation (deny when non_interactive)" do
      action_plan = Taskmate::Security::ActionGate::ActionPlan.build
      expect(policy.authorize_jira_write(action_plan)).to eq(:deny)
    end

    it "defaults to requiring AI consent (deny when non_interactive)" do
      result = policy.authorize_ai_call(issue_file: issue_double, provider: "openai")
      expect(result).to eq(:deny)
    end

    it "defaults to enabling secret detection (blocks secret content)" do
      # require_consent_for_ai is true by default; non_interactive means consent
      # is denied — but secret content should be blocked before reaching consent
      secret_policy = described_class.new(
        workspace_path: workspace,
        non_interactive: false,
        consent_manager: Taskmate::Security::FakeConsentManager.new(response: :allow)
      )
      secret_issue = issue_double(body: "password: super_secret_token_abc123xyz")
      expect(secret_policy.authorize_ai_call(issue_file: secret_issue, provider: "openai")).to eq(:deny)
    end
  end
end
