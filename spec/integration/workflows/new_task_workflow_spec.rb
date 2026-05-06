require "spec_helper"
require "taskmate/core/create_local_task"
require "taskmate/core/push_issue"
require "taskmate/security/policy"
require "taskmate/security/action_gate"
require "taskmate/ai/providers/fake_provider"
require "taskmate/skills/runner"

# New task workflow: create-task → push
RSpec.describe "New task workflow", type: :integration do
  let(:workspace) { create_temp_workspace(initialized: true) }
  let(:jira_client) { FakeJiraClient.new }

  let(:fake_policy) do
    policy = instance_double(Taskmate::Security::Policy)
    allow(policy).to receive(:authorize_ai_call).and_return(:allow)
    allow(policy).to receive(:authorize_jira_write).and_return(:allow)
    allow(policy).to receive(:write_ai_audit).and_return("/tmp/ai-audit.yml")
    allow(policy).to receive(:write_action_audit).and_return("/tmp/audit.yml")
    policy
  end

  # ActionGate that auto-confirms without prompting
  let(:fake_action_gate) do
    gate = instance_double(Taskmate::Security::ActionGate)
    allow(gate).to receive(:confirm).and_return(:allow)
    gate
  end

  let(:fake_ai) do
    Taskmate::AI::Providers::FakeProvider.new(
      default_response: <<~MD
        ---
        summary: Add password reset feature
        issue_type: Story
        priority: Medium
        labels:
          - auth
        ---

        ## Description

        Implement a password reset flow for users who forgot their credentials.

        ## Acceptance Criteria

        - [ ] User can request a reset email
        - [ ] Reset link expires after 1 hour
        - [ ] Password is updated on confirmation
      MD
    )
  end

  let(:skill_runner) do
    Taskmate::Skills::Runner.new(
      workspace_path:  workspace,
      ai_provider:     fake_ai,
      security_policy: fake_policy
    )
  end

  it "creates a local task and pushes it to Jira" do
    # Step 1: Create local task
    create_result = Taskmate::Core::CreateLocalTask.new(
      workspace_path: workspace,
      skill_runner:   skill_runner,
      action_gate:    fake_action_gate
    ).call("Add password reset feature")

    expect(create_result.applied).to be true
    expect(File.exist?(create_result.path)).to be true

    issue_file = Taskmate::Workspace::IssueFile.read(create_result.path)
    expect(issue_file.key).to be_nil
    expect(issue_file.sync_state).to eq("new_local")

    # Step 2: Push to Jira (creates new issue)
    push_result = Taskmate::Core::PushIssue.new(
      workspace_path:  workspace,
      jira_client:     jira_client,
      security_policy: fake_policy
    ).call(create_result.path)

    expect(push_result.applied).to be true
    expect(jira_client.created_issues.size).to eq(1)

    new_key = jira_client.created_issues.first["key"]
    expect(new_key).to match(/\ATEST-\d+\z/)

    # Local file should have been renamed/moved to the new key
    new_path = File.join(workspace, "issues", "#{new_key}.md")
    expect(File.exist?(new_path)).to be true
    expect(push_result.issue_file.key).to eq(new_key)
  end
end
