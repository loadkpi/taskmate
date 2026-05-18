require "taskmate/doctor/checks/workspace_yml_check"
require "taskmate/doctor/checks/directories_check"
require "taskmate/doctor/checks/taskmateignore_check"
require "taskmate/doctor/checks/skills_check"
require "taskmate/doctor/checks/no_secrets_check"
require "taskmate/doctor/checks/security_config_check"
require "taskmate/doctor/checks/jira_check"
require "taskmate/doctor/checks/ai_check"

module Taskmate
  module Doctor
    class Runner
      def initialize(workspace_path:)
        @workspace_path = workspace_path
        @checks = build_checks
      end

      def run
        @checks.each(&:run)
        @checks
      end

      def register(check)
        @checks << check
      end

      private

      def build_checks
        [
          Checks::WorkspaceYmlCheck.new(workspace_path: @workspace_path),
          Checks::DirectoriesCheck.new(workspace_path: @workspace_path),
          Checks::TaskmateignoreCheck.new(workspace_path: @workspace_path),
          Checks::SkillsCheck.new(workspace_path: @workspace_path),
          Checks::NoSecretsCheck.new(workspace_path: @workspace_path),
          Checks::SecurityConfigCheck.new(workspace_path: @workspace_path),
          Checks::JiraCheck.new(workspace_path: @workspace_path),
          Checks::AiCheck.new(workspace_path: @workspace_path)
        ]
      end
    end
  end
end
