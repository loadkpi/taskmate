require "spec_helper"
require "taskmate/security/policy"
require "taskmate/security/consent_manager"
require "taskmate/ai/providers/fake_provider"
require "taskmate/skills/runner"
require "taskmate/workspace/issue_file"

RSpec.describe "AI disclosure and redaction integration" do
  let(:workspace) { create_temp_workspace(initialized: true) }

  def build_issue(body:, key: "SAR-1", path: nil)
    fm  = { "key" => key, "summary" => "Test", "issue_type" => "Task" }
    iss = Taskmate::Workspace::IssueFile.build(frontmatter: fm, body: body, path: path)
    if path
      FileUtils.mkdir_p(File.dirname(path))
      iss.write(path)
      Taskmate::Workspace::IssueFile.read(path)
    else
      iss
    end
  end

  def runner_with(consent_response:, provider_response: "AI result")
    provider = Taskmate::AI::Providers::FakeProvider.new(
      default_response: provider_response
    )
    consent_mgr = Taskmate::Security::FakeConsentManager.new(response: consent_response)
    policy = Taskmate::Security::Policy.new(
      workspace_path: workspace,
      consent_manager: consent_mgr
    )
    [
      Taskmate::Skills::Runner.new(
        workspace_path: workspace,
        ai_provider: provider,
        security_policy: policy
      ),
      provider
    ]
  end

  context "when consent is granted" do
    it "calls the AI provider and returns a result" do
      runner, provider = runner_with(consent_response: :allow)
      issue = build_issue(body: "Fix the login button.")

      result = runner.run(skill_id: "improve-task", issue_file: issue)

      expect(result.response_text).to eq("AI result")
      expect(provider.call_count).to eq(1)
    end

    it "writes an audit file after the AI call" do
      runner, = runner_with(consent_response: :allow)
      issue = build_issue(body: "Fix the login button.",
                          path: File.join(workspace, "issues", "SAR-1.md"))

      runner.run(skill_id: "improve-task", issue_file: issue)

      audit_files = Dir.glob(File.join(workspace, "audit", "ai", "*.yml"))
      expect(audit_files).not_to be_empty
    end

    it "does not store raw prompt in audit" do
      runner, = runner_with(consent_response: :allow)
      issue = build_issue(body: "Fix the login button.",
                          path: File.join(workspace, "issues", "SAR-1.md"))

      runner.run(skill_id: "improve-task", issue_file: issue)

      audit_file = Dir.glob(File.join(workspace, "audit", "ai", "*.yml")).first
      content    = File.read(audit_file)
      expect(content).not_to include("Fix the login button")
      expect(content).to include("sha256:")
    end
  end

  context "when consent is denied" do
    it "raises ConsentDeniedError and makes no AI call" do
      runner, provider = runner_with(consent_response: :deny)
      issue = build_issue(body: "Normal description.")

      expect do
        runner.run(skill_id: "improve-task", issue_file: issue)
      end.to raise_error(Taskmate::ConsentDeniedError)

      expect(provider.call_count).to eq(0)
    end
  end

  context "when secrets are detected in issue content" do
    it "blocks before consent and makes no AI call" do
      runner, provider = runner_with(consent_response: :allow)
      issue = build_issue(body: "Token: AKIAIOSFODNN7EXAMPLE is hardcoded.")

      expect do
        runner.run(skill_id: "improve-task", issue_file: issue)
      end.to raise_error(Taskmate::ConsentDeniedError)

      expect(provider.call_count).to eq(0)
    end
  end

  context "provider identity in disclosure" do
    it "uses provider class name in audit" do
      runner, = runner_with(consent_response: :allow)
      issue = build_issue(body: "Fix the bug.",
                          path: File.join(workspace, "issues", "SAR-1.md"))

      runner.run(skill_id: "improve-task", issue_file: issue)

      audit_file = Dir.glob(File.join(workspace, "audit", "ai", "*.yml")).first
      require "yaml"
      data = YAML.safe_load_file(audit_file)
      expect(data["provider"]).to include("FakeProvider")
    end
  end
end
