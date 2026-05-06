require "fileutils"
require "taskmate/workspace/issue_file"
require "taskmate/workspace/frontmatter_file"
require "taskmate/skills/runner"

module Taskmate
  module Core
    class CreateLocalTask
      CreateResult = Struct.new(
        :issue_file, :path, :applied,
        keyword_init: true
      )

      def initialize(workspace_path:, skill_runner:, action_gate:)
        @workspace_path = workspace_path
        @skill_runner   = skill_runner
        @action_gate    = action_gate
      end

      def call(short_description)
        # Build a minimal issue stub for security context (no key)
        stub = Workspace::IssueFile.build(
          frontmatter: { "key" => nil, "summary" => short_description, "issue_type" => "Task" },
          body:        short_description
        )

        run_result = @skill_runner.run(
          skill_id:    "create-task",
          issue_file:  stub,
          instruction: short_description
        )

        proposed_content = run_result.response_text

        puts proposed_content
        puts "\n"

        answer = @action_gate.confirm(
          Security::ActionGate::ActionPlan.build(
            field_changes: [],
            warnings:      []
          )
        )

        return CreateResult.new(issue_file: nil, path: nil, applied: false) if answer == :deny

        issue_file = build_issue_file(short_description, proposed_content)
        path       = issue_file.default_path(@workspace_path)
        FileUtils.mkdir_p(File.dirname(path))
        issue_file.write(path)

        CreateResult.new(issue_file: issue_file, path: path, applied: true)
      end

      private

      def build_issue_file(summary, content)
        # Try to parse proposed content as frontmatter file; fall back to plain body
        begin
          ff = Workspace::FrontmatterFile.parse(content)
          fm = ff.frontmatter
          fm["key"]        = nil               # always nil for local drafts
          fm["sync_state"] = "new_local"
          fm["summary"]    ||= summary
          fm["issue_type"] ||= "Task"
          Workspace::IssueFile.build(frontmatter: fm, body: ff.body)
        rescue InvalidFrontmatterError
          Workspace::IssueFile.build(
            frontmatter: {
              "key"        => nil,
              "summary"    => summary,
              "issue_type" => "Task",
              "sync_state" => "new_local"
            },
            body: content
          )
        end
      end
    end
  end
end
