require "taskmate/doctor/check"
require "taskmate/doctor/checks/config_reader"

module Taskmate
  module Doctor
    module Checks
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

          base_url    = ENV.fetch("TASKMATE_JIRA_URL",   safe_dig(config, "jira", "base_url"))
          email       = ENV.fetch("TASKMATE_JIRA_EMAIL",  "")
          api_token   = ENV.fetch("TASKMATE_JIRA_TOKEN",  "")
          project_key = safe_dig(config, "jira", "default_project")

          if base_url.empty?
            return skip!("Jira not configured in workspace.yml and TASKMATE_JIRA_URL not set")
          end

          if email.empty? || api_token.empty?
            return fail!("Authentication failed. Check TASKMATE_JIRA_EMAIL and TASKMATE_JIRA_TOKEN.")
          end

          begin
            require "taskmate/jira/client"
            client = Jira::Client.new(base_url: base_url, email: email, api_token: api_token,
                                      max_retries: 1)
            if project_key.empty?
              # Just verify credentials with a minimal check
              client.search_issues(jql: "ORDER BY created DESC", limit: 1)
              ok!("Jira reachable and credentials valid (#{base_url})")
            else
              client.get_project(project_key)
              ok!("Jira reachable; project #{project_key} accessible (#{base_url})")
            end
          rescue JiraAuthError => e
            fail!("Authentication failed. Check TASKMATE_JIRA_EMAIL and TASKMATE_JIRA_TOKEN.")
          rescue JiraNotFoundError
            fail!("Project #{project_key} not found on #{base_url}.")
          rescue => e
            fail!("Jira unreachable (#{base_url}): #{e.message}")
          end
        end
      end
    end
  end
end
