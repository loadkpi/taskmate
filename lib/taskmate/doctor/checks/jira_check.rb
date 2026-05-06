require "taskmate/doctor/check"
require "taskmate/doctor/checks/config_reader"

module Taskmate
  module Doctor
    module Checks
      # Full online Jira connectivity check is added in M4-T8.
      # Here we only report skip/configured status based on workspace.yml.
      class JiraCheck < Check
        include ConfigReader

        def initialize(workspace_path:)
          super(name: "Jira connectivity", description: "Jira credentials and project are accessible")
          @workspace_path = workspace_path
        end

        def run
          config = load_workspace_config(@workspace_path)
          case config
          when :not_found
            return skip!("workspace.yml not found")
          when :invalid_yaml, :invalid_structure
            return skip!("workspace.yml is malformed — skipping Jira check")
          end

          jira_url = safe_dig(config, "tracker", "base_url")
          if jira_url.empty?
            skip!("Jira not configured in workspace.yml (online check added in M4)")
          else
            skip!("Jira configured (#{jira_url}) — online connectivity check added in M4")
          end
        end
      end
    end
  end
end
