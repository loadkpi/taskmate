require "json"

module Taskmate
  module Rendering
    # Shared JSON rendering helpers for CLI commands.
    # Commands may use these directly or implement their own render_json methods.
    module JsonRenderer
      def render_json(data)
        puts JSON.pretty_generate(data)
      end

      def json_issue(issue_file)
        {
          "key" => issue_file.key,
          "summary" => issue_file.summary,
          "status" => issue_file.status,
          "issue_type" => issue_file.issue_type,
          "priority" => issue_file.priority,
          "labels" => issue_file.labels,
          "assignee" => issue_file.frontmatter["assignee"],
          "sync_state" => issue_file.sync_state
        }
      end
    end
  end
end
