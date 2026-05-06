require "fileutils"
require "taskmate/workspace/issue_file"
require "taskmate/skills/runner"

module Taskmate
  module Core
    class ReviewIssue
      ReviewResult = Struct.new(
        :issue_file, :review_markdown, :readiness_score, :review_path,
        keyword_init: true
      )

      SCORE_REGEX = /readiness.{0,20}score[:\s]+(\d+)/i

      def initialize(workspace_path:, skill_runner:)
        @workspace_path = workspace_path
        @skill_runner   = skill_runner
      end

      def call(key)
        issue_path = File.join(@workspace_path, "issues", "#{key}.md")
        raise IssueNotFoundError, "No local file for #{key}." unless File.exist?(issue_path)

        issue = Workspace::IssueFile.read(issue_path)

        run_result = @skill_runner.run(
          skill_id:   "review-task",
          issue_file: issue
        )

        review_markdown  = run_result.response_text
        readiness_score  = extract_score(review_markdown)
        review_path      = write_review(key, review_markdown)

        ReviewResult.new(
          issue_file:     issue,
          review_markdown: review_markdown,
          readiness_score: readiness_score,
          review_path:     review_path
        )
      end

      private

      def extract_score(text)
        m = SCORE_REGEX.match(text)
        m ? m[1].to_i : nil
      end

      def write_review(key, markdown)
        dir  = File.join(@workspace_path, "reviews")
        FileUtils.mkdir_p(dir)
        path = File.join(dir, "#{key}.review.md")
        tmp  = "#{path}.tmp.#{Process.pid}"
        File.write(tmp, markdown, encoding: "utf-8")
        File.rename(tmp, path)
        path
      end
    end
  end
end
