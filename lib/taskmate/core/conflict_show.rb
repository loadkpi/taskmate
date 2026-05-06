require "fileutils"
require "taskmate/workspace/issue_file"
require "taskmate/jira/conflict_detector"

module Taskmate
  module Core
    class ConflictShow
      ConflictShowResult = Struct.new(
        :local_issue, :jira_issue, :conflict_result,
        keyword_init: true
      )

      def initialize(workspace_path:, jira_client:, story_points_field: nil)
        @workspace_path     = workspace_path
        @jira_client        = jira_client
        @detector           = Jira::ConflictDetector.new(story_points_field: story_points_field)
        require "taskmate/jira/issue_mapper"
        @mapper             = Jira::IssueMapper.new(story_points_field: story_points_field)
      end

      def call(key)
        local_path = File.join(@workspace_path, "issues", "#{key}.md")
        raise IssueNotFoundError, "No local file for #{key}." unless File.exist?(local_path)

        local_issue = Workspace::IssueFile.read(local_path)
        jira_raw    = @jira_client.find_issue(key)
        jira_issue, = @mapper.map(jira_raw)

        conflict_result = @detector.detect(
          local_issue:    local_issue,
          jira_issue_raw: jira_raw
        )

        ConflictShowResult.new(
          local_issue:     local_issue,
          jira_issue:      jira_issue,
          conflict_result: conflict_result
        )
      end

      def save_as_conflict(key)
        jira_raw    = @jira_client.find_issue(key)
        jira_issue, = @mapper.map(jira_raw)

        timestamp = Time.now.strftime("%Y%m%d%H%M%S")
        dir       = File.join(@workspace_path, "issues", "conflicts")
        FileUtils.mkdir_p(dir)

        path = File.join(dir, "#{key}.jira.#{timestamp}.md")
        jira_issue.write(path)
        path
      end

      def overwrite_local(key)
        jira_raw    = @jira_client.find_issue(key)
        jira_issue, = @mapper.map(jira_raw)

        issue_path  = File.join(@workspace_path, "issues", "#{key}.md")
        jira_issue.jira_source_hash = jira_issue.jira_source_hash
        jira_issue.last_synced_local_hash = jira_issue.jira_source_hash
        jira_issue.write(issue_path)
        issue_path
      end
    end
  end
end
