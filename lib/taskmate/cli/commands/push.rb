require "taskmate/core/push_issue"
require "taskmate/security/policy"
require "taskmate/cli/output"
require "taskmate/rendering/json_renderer"

module Taskmate
  module CLI
    module Commands
      class Push
        include Taskmate::Rendering::JsonRenderer
        VALID_FORMATS = %w[text json].freeze

        def initialize(options = {})
          @options = options
        end

        def call(key, workspace_path = Dir.pwd)
          fmt     = @options[:format].to_s
          dry_run = @options[:dry_run] || false

          unless VALID_FORMATS.include?(fmt)
            raise Taskmate::ValidationError, "Invalid format '#{fmt}'. Valid: #{VALID_FORMATS.join(', ')}"
          end

          require "taskmate/doctor/checks/config_reader"
          extend Taskmate::Doctor::Checks::ConfigReader

          config = load_workspace_config(workspace_path)

          client  = build_jira_client(config)
          policy  = Security::Policy.new(workspace_path: workspace_path)

          result = Core::PushIssue.new(
            workspace_path: workspace_path,
            jira_client: client,
            security_policy: policy,
            push_config: build_push_config(config),
            story_points_field: story_points_field(config)
          ).call(key, dry_run: dry_run)

          if fmt == "json"
            render_json(result)
          else
            render_text(result)
          end
        end

        private

        def render_text(result)
          if result.dry_run
            CLI::Output.info("[DRY RUN] Would push #{result.issue_file.key}")
            result.action_plan.field_changes.each do |c|
              CLI::Output.info("  #{c.field}: #{c.from} → #{c.to}")
            end
            result.action_plan.warnings.each { |w| CLI::Output.warn("  ! #{w}") }
          elsif result.applied
            CLI::Output.success("Pushed #{result.issue_file.key} to Jira.")
            CLI::Output.info("  Audit: #{result.audit_path}") if result.audit_path
          else
            CLI::Output.info("Push cancelled.")
          end
        end

        def render_json(result)
          super(
            "key" => result.issue_file.key,
            "applied" => result.applied,
            "dry_run" => result.dry_run
          )
        end

        def build_jira_client(config)
          require "taskmate/jira/client"
          require "taskmate/doctor/checks/config_reader"
          extend Taskmate::Doctor::Checks::ConfigReader

          base_url = jira_base_url(config)
          email    = ENV["TASKMATE_JIRA_EMAIL"] || ""
          token    = ENV["TASKMATE_JIRA_TOKEN"] || ""

          if base_url.empty? || email.empty? || token.empty?
            raise Taskmate::JiraAuthError,
                  "Missing Jira credentials. Set TASKMATE_JIRA_URL, TASKMATE_JIRA_EMAIL, TASKMATE_JIRA_TOKEN."
          end

          Jira::Client.new(base_url: base_url, email: email, api_token: token)
        end

        def build_push_config(config)
          return default_push_config unless config.is_a?(Hash)

          allowed = Array(config.dig("push", "allowed_fields"))
          return default_push_config if allowed.empty?

          all_fields = %w[summary description labels components priority]
          all_fields.to_h { |f| ["allow_#{f}", allowed.include?(f)] }
        end

        def default_push_config
          # Fail-closed: when no explicit allowlist is configured, allow the standard safe fields
          %w[summary description labels components priority]
            .to_h { |f| ["allow_#{f}", true] }
        end
      end
    end
  end
end
