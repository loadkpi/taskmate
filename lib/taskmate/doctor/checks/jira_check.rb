require "taskmate/doctor/check"
require "taskmate/config"

module Taskmate
  module Doctor
    module Checks
      class JiraCheck < Check
        def initialize(workspace_path:)
          super(name: "Jira connectivity", description: "Jira credentials and project are accessible")
          @workspace_path = workspace_path
        end

        def run
          raw = Config::Loader.load_raw(@workspace_path)
          case raw
          when :not_found then return skip!("workspace.yml not found")
          when :invalid_yaml, :invalid_structure then return skip!("workspace.yml is malformed — skipping Jira check")
          end

          cfg = Config::Loader.load(@workspace_path)
          check_jira_config(cfg)
        end

        private

        def check_jira_config(cfg)
          base_url    = cfg.tracker.base_url
          email       = cfg.auth.email
          api_token   = cfg.auth.api_token
          project_key = cfg.tracker.default_project

          return skip!("Jira not configured in workspace.yml and TASKMATE_JIRA_URL not set") if base_url.empty?
          if email.empty? || api_token.empty?
            return fail!("Authentication failed. Check TASKMATE_JIRA_EMAIL and TASKMATE_JIRA_TOKEN.")
          end

          check_connectivity(base_url, email, api_token, project_key)
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
