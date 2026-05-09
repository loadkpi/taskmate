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
          when :not_found             then return skip!("workspace.yml not found")
          when :invalid_yaml, :invalid_structure then return skip!("workspace.yml is malformed — skipping Jira check")
          end
          check_jira_config(config)
        end

        private

        def check_jira_config(config)
          base_url    = resolve_base_url(config)
          email       = ENV.fetch("TASKMATE_JIRA_EMAIL", "")
          api_token   = ENV.fetch("TASKMATE_JIRA_TOKEN", "")
          project_key = resolve_project_key(config)

          return skip!("Jira not configured in workspace.yml and TASKMATE_JIRA_URL not set") if base_url.empty?
          return fail!("Authentication failed. Check TASKMATE_JIRA_EMAIL and TASKMATE_JIRA_TOKEN.") if email.empty? || api_token.empty?

          check_connectivity(base_url, email, api_token, project_key)
        end

        def resolve_base_url(config)
          ENV.fetch("TASKMATE_JIRA_URL",
                    safe_dig(config, "tracker", "base_url").then { |v| v.empty? ? safe_dig(config, "jira", "base_url") : v })
        end

        def resolve_project_key(config)
          safe_dig(config, "tracker", "default_project").then { |v| v.empty? ? safe_dig(config, "jira", "default_project") : v }
        end

        def check_connectivity(base_url, email, api_token, project_key)
          require "taskmate/jira/client"
          client = Jira::Client.new(base_url: base_url, email: email, api_token: api_token, max_retries: 1)
          if project_key.empty?
            client.search_issues(jql: "ORDER BY created DESC", limit: 1)
            ok!("Jira reachable and credentials valid (#{base_url})")
          else
            client.get_project(project_key)
            ok!("Jira reachable; project #{project_key} accessible (#{base_url})")
          end
        rescue JiraAuthError
          fail!("Authentication failed. Check TASKMATE_JIRA_EMAIL and TASKMATE_JIRA_TOKEN.")
        rescue JiraNotFoundError
          fail!("Project #{project_key} not found on #{base_url}.")
        rescue StandardError => e
          fail!("Jira unreachable (#{base_url}): #{e.message}")
        end
      end
    end
  end
end
