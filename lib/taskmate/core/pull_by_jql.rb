require "taskmate/core/pull_issue"

module Taskmate
  module Core
    class PullByJql
      BatchResult = Struct.new(:pulled, :failed, :total, keyword_init: true)
      FailedItem  = Struct.new(:key, :error, keyword_init: true)

      def initialize(workspace_path:, jira_client:, story_points_field: nil)
        @workspace_path     = workspace_path
        @jira_client        = jira_client
        @pull_issue         = PullIssue.new(
          workspace_path: workspace_path,
          jira_client: jira_client,
          story_points_field: story_points_field
        )
      end

      def call(jql:, limit: 50)
        issues  = @jira_client.search_issues(jql: jql, limit: limit)
        pulled  = []
        failed  = []

        issues.each do |raw|
          key = raw["key"]
          begin
            result = @pull_issue.call(key)
            pulled << result
          rescue StandardError => e
            failed << FailedItem.new(key: key, error: e.message)
          end
        end

        BatchResult.new(pulled: pulled, failed: failed, total: issues.size)
      end
    end
  end
end
