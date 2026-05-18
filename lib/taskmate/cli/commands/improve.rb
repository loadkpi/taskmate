require "taskmate/core/improve_issue"
require "taskmate/skills/runner"
require "taskmate/security/policy"
require "taskmate/security/action_gate"

module Taskmate
  module CLI
    module Commands
      class Improve
        def initialize(options = {})
          @options = options
        end

        def call(key, workspace_path = Dir.pwd)
          runner = build_runner(workspace_path)
          gate   = Security::ActionGate.new

          result = Core::ImproveIssue.new(
            workspace_path: workspace_path,
            skill_runner: runner,
            action_gate: gate
          ).call(key,
                 instruction: @options[:instruction],
                 output_path: @options[:output])

          if result.applied
            puts "Applied improvement to #{key}."
          else
            puts "Improvement discarded."
          end
        end

        private

        def build_runner(workspace_path)
          require "taskmate/ai/client"
          require "taskmate/config"

          cfg      = Config::Loader.load(workspace_path)
          policy   = Security::Policy.new(workspace_path: workspace_path)
          provider = AI::Client.from_app_config(cfg)

          Skills::Runner.new(
            workspace_path: workspace_path,
            ai_provider: provider,
            security_policy: policy
          )
        end
      end
    end
  end
end
