require "taskmate/workspace/issue_file"
require "taskmate/workspace/frontmatter_file"
require "taskmate/workspace/diff"
require "taskmate/skills/runner"

module Taskmate
  module Core
    class ImproveIssue
      ImproveResult = Struct.new(
        :issue_file, :proposed_content, :diff, :applied, :audit_path,
        keyword_init: true
      )

      def initialize(workspace_path:, skill_runner:, action_gate:)
        @workspace_path = workspace_path
        @skill_runner   = skill_runner
        @action_gate    = action_gate
      end

      def call(key, instruction: nil, output_path: nil)
        issue_path = File.join(@workspace_path, "issues", "#{key}.md")
        raise IssueNotFoundError, "No local file for #{key}." unless File.exist?(issue_path)

        issue    = Workspace::IssueFile.read(issue_path)
        proposed = @skill_runner.run(skill_id: "improve-task", issue_file: issue,
                                     instruction: instruction).response_text
        diff     = Workspace::Diff.new(issue_key: key, original: issue.raw_content, modified: proposed)

        confirm_and_apply(issue, proposed, diff, output_path || issue_path)
      end

      private

      def confirm_and_apply(issue, proposed, diff, dest)
        answer = @action_gate.confirm(
          Security::ActionGate::ActionPlan.build(field_changes: [], warnings: []),
          preamble: diff.to_s
        )

        if answer == :deny
          return ImproveResult.new(issue_file: issue, proposed_content: proposed,
                                   diff: diff, applied: false, audit_path: nil)
        end

        write_proposed(proposed, dest)
        ImproveResult.new(issue_file: issue, proposed_content: proposed,
                          diff: diff, applied: true, audit_path: nil)
      end

      def write_proposed(content, path)
        tmp = "#{path}.tmp.#{Process.pid}"
        File.write(tmp, content, encoding: "utf-8")
        File.rename(tmp, path)
      end
    end
  end
end
