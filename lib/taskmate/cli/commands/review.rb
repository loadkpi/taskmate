require "taskmate/core/review_issue"
require "taskmate/skills/runner"
require "taskmate/security/policy"

module Taskmate
  module CLI
    module Commands
      class Review
        VALID_FORMATS = %w[text json].freeze

        def initialize(options = {})
          @options = options
        end

        def call(key, workspace_path = Dir.pwd)
          fmt = @options[:format].to_s
          fmt = "text" if fmt.empty?
          unless VALID_FORMATS.include?(fmt)
            raise Taskmate::ValidationError, "Invalid format '#{fmt}'. Valid: #{VALID_FORMATS.join(", ")}"
          end

          runner = build_runner(workspace_path)

          result = Core::ReviewIssue.new(
            workspace_path: workspace_path,
            skill_runner:   runner
          ).call(key)

          if fmt == "json"
            render_json(result)
          else
            render_text(result)
          end
        end

        private

        def render_text(result)
          puts result.review_markdown
          puts "\nReview written to #{result.review_path}"
          puts "Readiness score: #{result.readiness_score}" if result.readiness_score
        end

        def render_json(result)
          require "json"
          puts JSON.pretty_generate(
            "review_markdown"  => result.review_markdown,
            "review_path"      => result.review_path,
            "readiness_score"  => result.readiness_score
          )
        end

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
