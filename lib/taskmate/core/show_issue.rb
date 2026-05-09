require "taskmate/workspace/issue_file"

module Taskmate
  module Core
    class ShowIssue
      ShowResult = Struct.new(:issue_file, :format, keyword_init: true)

      def initialize(workspace_path:)
        @workspace_path = workspace_path
      end

      def call(key, format: :text, _metadata: false)
        path = issue_path(key)
        raise IssueNotFoundError, "No local file for #{key}. Run `taskmate pull #{key}` first." unless File.exist?(path)

        issue = Workspace::IssueFile.read(path)
        ShowResult.new(issue_file: issue, format: format)
      end

      private

      def issue_path(key)
        File.join(@workspace_path, "issues", "#{key}.md")
      end
    end
  end
end
