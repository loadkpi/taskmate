require "taskmate/workspace/issue_file"
require "taskmate/jira/markdown_validator"

module Taskmate
  module Core
    class ValidateIssue
      ValidateResult = Struct.new(:issue_file, :errors, keyword_init: true) do
        def valid?
          errors.empty?
        end
      end

      def initialize(workspace_path:)
        @workspace_path = workspace_path
        @validator      = Jira::MarkdownValidator.new
      end

      def call(key)
        path = File.join(@workspace_path, "issues", "#{key}.md")
        raise IssueNotFoundError, "No local file for #{key}." unless File.exist?(path)

        issue  = Workspace::IssueFile.read(path)
        errors = @validator.validate(issue.body)

        ValidateResult.new(issue_file: issue, errors: errors)
      end
    end
  end
end
