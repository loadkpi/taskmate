require "taskmate/core/conflict_show"

module Taskmate
  module CLI
    module Commands
      class Conflict
        def initialize(options = {})
          @options = options
        end

        def show(key, workspace_path = Dir.pwd)
          client = build_jira_client(workspace_path)
          result = Core::ConflictShow.new(
            workspace_path: workspace_path,
            jira_client: client
          ).call(key)

          cr = result.conflict_result

          if cr.status == :no_conflict
            puts "No conflict detected for #{key}."
            return
          end

          puts "CONFLICT: #{key}"
          puts "Fields changed on Jira side: #{cr.changed_fields.join(', ')}"
          puts "\nLocal jira_source_hash : #{cr.local_hash}"
          puts "Current Jira hash      : #{cr.jira_hash}"
          puts "\nOptions:"
          puts "  taskmate pull #{key} --save-as-conflict    # keep local, save Jira version"
          puts "  taskmate pull #{key} --overwrite-local     # discard local, use Jira version"
        end

        private

        def build_jira_client(workspace_path)
          require "taskmate/jira/client"
          require "taskmate/doctor/checks/config_reader"
          extend Taskmate::Doctor::Checks::ConfigReader

          config   = load_workspace_config(workspace_path)
          base_url = jira_base_url(config)
          email    = ENV["TASKMATE_JIRA_EMAIL"] || ""
          token    = ENV["TASKMATE_JIRA_TOKEN"] || ""

          raise Taskmate::JiraAuthError, "Missing Jira credentials." if base_url.empty? || email.empty? || token.empty?

          Jira::Client.new(base_url: base_url, email: email, api_token: token)
        end
      end
    end
  end
end
