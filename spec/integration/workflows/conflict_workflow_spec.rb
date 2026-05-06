require "spec_helper"
require "taskmate/core/pull_issue"
require "taskmate/core/push_issue"
require "taskmate/security/policy"

# Conflict workflow: pull → remote change → push blocked → resolve
RSpec.describe "Conflict workflow", type: :integration do
  let(:workspace) { create_temp_workspace(initialized: true) }
  let(:jira_client) do
    FakeJiraClient.new(issues: {
      "TEST-2" => {
        "summary" => "Initial summary",
        "labels"  => [],
        "status"  => { "name" => "To Do", "id" => "1",
                       "statusCategory" => { "key" => "new" } }
      }
    })
  end

  let(:fake_policy) do
    policy = instance_double(Taskmate::Security::Policy)
    allow(policy).to receive(:authorize_jira_write).and_return(:allow)
    allow(policy).to receive(:write_action_audit).and_return("/tmp/audit.yml")
    policy
  end

  def pull_issue(key)
    Taskmate::Core::PullIssue.new(
      workspace_path: workspace,
      jira_client:    jira_client
    ).call(key)
  end

  def push_issue(key)
    Taskmate::Core::PushIssue.new(
      workspace_path:  workspace,
      jira_client:     jira_client,
      security_policy: fake_policy
    ).call(key)
  end

  it "blocks push when Jira has changed since last pull" do
    # Step 1: Pull the issue
    pull_result = pull_issue("TEST-2")

    # Step 2: Edit locally
    content = File.read(pull_result.path)
    File.write(pull_result.path, content + "\nLocal addition.\n")

    # Step 3: Remote Jira changes the issue (simulates another user)
    jira_client.remote_update("TEST-2", "summary" => "Remote change by another user")

    # Step 4: Push should raise ConflictError
    expect { push_issue("TEST-2") }.to raise_error(Taskmate::ConflictError, /conflicting changes/)
  end

  it "allows push after conflict is resolved by re-pulling" do
    pull_result = pull_issue("TEST-2")

    # Local edit
    content = File.read(pull_result.path)
    File.write(pull_result.path, content + "\nLocal addition.\n")

    # Remote change
    jira_client.remote_update("TEST-2", "summary" => "Remote change by another user")

    # Resolve by re-pulling (overwrites local with Jira's canonical version)
    pull_issue("TEST-2")

    # Push now succeeds — no local changes vs Jira baseline
    result = push_issue("TEST-2")
    expect(result.applied).to be true
  end
end
