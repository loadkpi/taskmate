require "taskmate/core/push_issue"
require "taskmate/security/policy"

module Taskmate
  module CLI
    module Commands
      class Push
        VALID_FORMATS = %w[text json].freeze

        def initialize(options = {})
          @options = options
        end

        def call(key, workspace_path = Dir.pwd)
          fmt     = @options[:format].to_s
          dry_run = @options[:dry_run] || false

          unless VALID_FORMATS.include?(fmt)
            raise Taskmate::ValidationError, "Invalid format '#{fmt}'. Valid: #{VALID_FORMATS.join(", ")}"
          end

          require "taskmate/doctor/checks/config_reader"
          extend Taskmate::Doctor::Checks::ConfigReader
          config = load_workspace_config(workspace_path)

          client  = build_jira_client(config)
          policy  = Security::Policy.new(workspace_path: workspace_path)

          result = Core::PushIssue.new(
            workspace_path:     workspace_path,
            jira_client:        client,
            security_policy:    policy,
            push_config:        build_push_config(config),
            story_points_field: config.is_a?(Hash) ? config.dig("jira", "story_points_field") : nil
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
            puts "[DRY RUN] Would push #{result.issue_file.key}"
            result.action_plan.field_changes.each do |c|
              puts "  #{c.field}: #{c.from} → #{c.to}"
            end
            result.action_plan.warnings.each { |w| warn "  ! #{w}" }
          elsif result.applied
            puts "Pushed #{result.issue_file.key} to Jira."
          else
            puts "Push cancelled."
          end
        end

        def render_json(result)
          require "json"
          puts JSON.pretty_generate(
            "key"     => result.issue_file.key,
            "applied" => result.applied,
            "dry_run" => result.dry_run
          )
        end

        def build_jira_client(config)
          require "taskmate/jira/client"

          base_url = ENV["TASKMATE_JIRA_URL"] || (config.is_a?(Hash) ? config.dig("jira", "base_url").to_s : "")
          email    = ENV["TASKMATE_JIRA_EMAIL"] || ""
          token    = ENV["TASKMATE_JIRA_TOKEN"]  || ""

          if base_url.empty? || email.empty? || token.empty?
            raise Taskmate::JiraAuthError, "Missing Jira credentials. Set TASKMATE_JIRA_URL, TASKMATE_JIRA_EMAIL, TASKMATE_JIRA_TOKEN."
          end

          Jira::Client.new(base_url: base_url, email: email, api_token: token)
        end

        def build_push_config(config)
          return {} unless config.is_a?(Hash)

          allowed = Array(config.dig("push", "allowed_fields"))
          return {} if allowed.empty?

          all_fields = %w[summary description labels components priority]
          all_fields.each_with_object({}) { |f, h| h["allow_#{f}"] = allowed.include?(f) }
        end
      end
    end
  end
end
