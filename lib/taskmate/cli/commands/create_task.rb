require "taskmate/core/create_local_task"
require "taskmate/skills/runner"
require "taskmate/security/policy"
require "taskmate/security/action_gate"

module Taskmate
  module CLI
    module Commands
      class CreateTask
        def initialize(options = {})
          @options = options
        end

        def call(description, workspace_path = Dir.pwd)
          runner = build_runner(workspace_path)
          gate   = Security::ActionGate.new

          result = Core::CreateLocalTask.new(
            workspace_path: workspace_path,
            skill_runner:   runner,
            action_gate:    gate
          ).call(description)

          if result.applied
            puts "Created #{result.path}"
          else
            puts "Discarded — no file created."
          end
        end

        private

        def build_runner(workspace_path)
          require "taskmate/ai/providers/fake_provider"
          policy   = Security::Policy.new(workspace_path: workspace_path)
          provider = AI::Providers::FakeProvider.new(
            default_response: "---\nkey:\nsummary: New task\nissue_type: Task\nsync_state: new_local\n---\n<!-- No AI provider configured. -->\n"
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
