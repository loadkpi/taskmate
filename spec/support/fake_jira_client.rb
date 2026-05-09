require "digest"

# Fake Jira client for integration tests.
# Pre-seeded with issues; tracks calls; supports create/update.
class FakeJiraClient
  attr_reader :created_issues, :updated_issues, :find_calls

  def initialize(issues: {})
    @issues = {} # key -> raw Jira fields hash
    @created_issues = []
    @updated_issues = []
    @find_calls     = []
    @next_key_seq   = 100

    issues.each { |key, fields| seed(key, fields) }
  end

  def seed(key, fields = {})
    @issues[key] = build_raw(key, fields)
  end

  def find_issue(key)
    @find_calls << key
    @issues.fetch(key) { raise Taskmate::IssueNotFoundError, "Not found: #{key}" }
  end

  def search_issues(jql:, limit: 50) # rubocop:disable Lint/UnusedMethodArgument
    # Simple implementation: return all seeded issues (ignores JQL)
    @issues.values.first(limit)
  end

  def create_issue(payload)
    key = "TEST-#{@next_key_seq += 1}"
    fields = payload["fields"] || {}
    @issues[key] = build_raw(key, {
                               "summary" => fields["summary"],
                               "description" => fields["description"],
                               "issuetype" => fields["issuetype"] || { "name" => "Task" }
                             })
    @created_issues << { "key" => key, "payload" => payload }
    { "key" => key }
  end

  def update_issue(key, payload)
    existing = @issues.fetch(key) { raise Taskmate::IssueNotFoundError, "Not found: #{key}" }
    @updated_issues << { "key" => key, "payload" => payload }
    fields = payload["fields"] || {}
    # Merge updates into stored issue
    fields.each do |field, val|
      existing["fields"][field] = val
    end
    {}
  end

  # Remote-side change simulation: update fields directly
  def remote_update(key, fields)
    @issues.fetch(key)["fields"].merge!(fields)
  end

  private

  def build_raw(key, fields = {})
    {
      "id" => "10#{key.gsub(/\D/, '')}",
      "key" => key,
      "fields" => {
        "summary" => fields["summary"] || "#{key} issue",
        "description" => fields["description"],
        "issuetype" => fields["issuetype"] || { "name" => "Story", "id" => "10001" },
        "status" => fields["status"] || { "name" => "To Do", "id" => "1",
                                          "statusCategory" => { "key" => "new" } },
        "priority" => fields["priority"] || { "name" => "Medium", "id" => "3" },
        "labels" => fields["labels"] || [],
        "components" => fields["components"] || [],
        "assignee" => fields["assignee"],
        "reporter" => fields["reporter"],
        "created" => "2025-01-01T00:00:00.000+0000",
        "updated" => "2025-01-01T00:00:00.000+0000"
      }
    }
  end
end
