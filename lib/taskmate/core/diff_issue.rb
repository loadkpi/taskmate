require "taskmate/workspace/issue_file"
require "taskmate/workspace/diff"

module Taskmate
  module Core
    class DiffIssue
      def initialize(workspace_path:)
        @workspace_path = workspace_path
      end

      def call(key)
        path = issue_path(key)
        raise IssueNotFoundError, "No local file for #{key}." unless File.exist?(path)

        issue = Workspace::IssueFile.read(path)
        Workspace::Diff.compute(issue)
      end

      private

      def issue_path(key)
        File.join(@workspace_path, "issues", "#{key}.md")
      end
    end
  end
end
