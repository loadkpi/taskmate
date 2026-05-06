require "taskmate/core/review_issue"
require "taskmate/skills/runner"
require "taskmate/security/policy"

module Taskmate
  module CLI
    module Commands
      class Review
        def initialize(options = {})
          @options = options
        end

        def call(key, workspace_path = Dir.pwd)
          runner = build_runner(workspace_path)

          result = Core::ReviewIssue.new(
            workspace_path: workspace_path,
            skill_runner:   runner
          ).call(key)

          puts result.review_markdown
          puts "\nReview written to #{result.review_path}"
          puts "Readiness score: #{result.readiness_score}" if result.readiness_score
        end

        private

        def build_runner(workspace_path)
          require "taskmate/ai/providers/fake_provider"
          policy   = Security::Policy.new(workspace_path: workspace_path)
          provider = AI::Providers::FakeProvider.new(
            default_response: "Readiness score: 70\n\nNo AI provider configured.\n"
          )
          Skills::Runner.new(
            workspace_path:  workspace_path,
            ai_provider:     provider,
            security_policy: policy
          )
        end
      end
    end
  end
end
