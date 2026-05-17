require "taskmate/core/pull_issue"
require "taskmate/core/pull_by_jql"
require "taskmate/cli/output"
require "taskmate/rendering/json_renderer"

module Taskmate
  module CLI
    module Commands
      class Pull
        include Taskmate::Rendering::JsonRenderer
        VALID_FORMATS = %w[text json].freeze

        def initialize(options = {})
          @options = options
        end

        def call(key = nil, workspace_path = Dir.pwd)
          fmt_str = @options[:format].to_s
          unless VALID_FORMATS.include?(fmt_str)
            raise Taskmate::ValidationError, "Invalid format '#{fmt_str}'. Valid: #{VALID_FORMATS.join(', ')}"
          end

          jql   = @options[:jql]
          limit = (@options[:limit] || 50).to_i

          client = build_jira_client(workspace_path)

          if jql
            call_jql(jql, limit, client, workspace_path, fmt_str)
          elsif key
            call_single(key, client, workspace_path, fmt_str)
          else
            raise Taskmate::ValidationError, "Provide a KEY or --jql flag"
          end
        end

        private

        def call_single(key, client, workspace_path, fmt)
          result = CLI::Output.with_spinner("Pulling #{key} from Jira") do
            Core::PullIssue.new(
              workspace_path: workspace_path,
              jira_client: client
            ).call(key)
          end

          if fmt == "json"
            render_single_json(result)
          else
            render_single_text(result)
          end
        end

        def call_jql(jql, limit, client, workspace_path, fmt)
          batch = CLI::Output.with_spinner("Pulling issues via JQL") do
            Core::PullByJql.new(
              workspace_path: workspace_path,
              jira_client: client
            ).call(jql: jql, limit: limit)
          end

          if fmt == "json"
            render_batch_json(batch)
          else
            render_batch_text(batch)
          end

          exit 1 if batch.failed.any?
        end

        def render_single_text(result)
          CLI::Output.success("Pulled #{result.issue_file.key} → #{result.path}")
          return unless result.unsupported_nodes.any?

          CLI::Output.warn("  Warning: unsupported ADF nodes: #{result.unsupported_nodes.join(', ')}")
          CLI::Output.warn("  ADF backup saved to #{result.adf_backup_path}")
        end

        def render_single_json(result)
          render_json(
            "key" => result.issue_file.key,
            "path" => result.path,
            "synced_path" => result.synced_path,
            "unsupported_nodes" => result.unsupported_nodes,
            "adf_backup_path" => result.adf_backup_path
          )
        end

        def render_batch_text(batch)
          puts "Pulled #{batch.pulled.size}/#{batch.total} issues."
          batch.failed.each { |f| warn "  FAILED #{f.key}: #{f.error}" }
        end

        def render_batch_json(batch)
          render_json(
            "total" => batch.total,
            "pulled" => batch.pulled.map { |r| { "key" => r.issue_file.key, "path" => r.path } },
            "failed" => batch.failed.map { |f| { "key" => f.key, "error" => f.error } }
          )
        end

        def build_jira_client(workspace_path)
          require "taskmate/jira/client"
          require "taskmate/doctor/checks/config_reader"
          extend Taskmate::Doctor::Checks::ConfigReader

          config   = load_workspace_config(workspace_path)
          base_url = jira_base_url(config)
          email    = ENV.fetch("TASKMATE_JIRA_EMAIL", "")
          token    = ENV.fetch("TASKMATE_JIRA_TOKEN", "")

          if base_url.empty? || email.empty? || token.empty?
            raise Taskmate::JiraAuthError,
                  "Missing Jira credentials. Set TASKMATE_JIRA_URL, TASKMATE_JIRA_EMAIL, TASKMATE_JIRA_TOKEN."
          end

          Jira::Client.new(base_url: base_url, email: email, api_token: token)
        end
      end
    end
  end
end
