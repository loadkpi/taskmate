require "spec_helper"
require "taskmate/core/pull_issue"
require "taskmate/core/push_issue"
require "taskmate/core/validate_issue"
require "taskmate/workspace/diff"
require "taskmate/security/policy"

# Full workflow: pull → edit → validate → diff → push
RSpec.describe "Full workflow", type: :integration do
  let(:workspace) { create_temp_workspace(initialized: true) }
  let(:jira_client) do
    FakeJiraClient.new(issues: {
      "TEST-1" => {
        "summary"  => "Original summary",
        "priority" => { "name" => "Low", "id" => "4" },
        "labels"   => [],
        "status"   => { "name" => "To Do", "id" => "1",
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

  it "pulls an issue, edits it locally, validates, diffs, and pushes" do
    # Step 1: Pull
    pull_result = pull_issue("TEST-1")
    expect(pull_result.issue_file.key).to eq("TEST-1")
    expect(File.exist?(pull_result.path)).to be true

    # Step 2: Edit locally — change summary line in frontmatter
    content = File.read(pull_result.path)
    updated = content.sub("Original summary", "Updated summary")
    File.write(pull_result.path, updated)

    # Step 3: Validate Markdown
    validate_result = Taskmate::Core::ValidateIssue.new(workspace_path: workspace).call("TEST-1")
    expect(validate_result.valid?).to be true

    # Step 4: Diff — should show changes
    issue_file = Taskmate::Workspace::IssueFile.read(pull_result.path)
    diff = Taskmate::Workspace::Diff.compute(issue_file)
    expect(diff.empty?).to be false  # local content differs from synced copy

    # Step 5: Push
    push_result = push_issue("TEST-1")
    expect(push_result.applied).to be true
    expect(jira_client.updated_issues.size).to eq(1)
    expect(jira_client.updated_issues.first["payload"]["fields"]).to have_key("summary")
  end
end
