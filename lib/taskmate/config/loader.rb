require "yaml"
require_relative "config"

module Taskmate
  module Config
    class Loader
      DEFAULT_PUSH_FIELDS = %w[summary description labels components priority].freeze

      DEFAULTS = {
        "tracker" => { "base_url" => "", "default_project" => "", "story_points_field" => nil },
        "ai" => { "provider" => "disabled", "model" => nil, "enabled" => true },
        "security" => {
          "require_consent_for_ai" => true,
          "require_confirm_for_push" => true,
          "secret_detection" => true
        },
        "push" => { "allowed_fields" => DEFAULT_PUSH_FIELDS }
      }.freeze

      # Returns an AppConfig value object.
      # Merges defaults < workspace.yml < ENV overrides.
      def self.load(workspace_path, env: ENV)
        raw = load_raw(workspace_path)
        raw = {} unless raw.is_a?(Hash)
        raw = deep_merge(DEFAULTS, raw)
        build_config(raw, env: env)
      end

      # Returns raw parsed content of workspace.yml, or a sentinel symbol.
      # Symbols: :not_found, :invalid_yaml, :invalid_structure
      def self.load_raw(workspace_path)
        path = File.join(workspace_path, "workspace.yml")
        return :not_found unless File.exist?(path)

        parsed = YAML.safe_load_file(path)
        return :invalid_structure unless parsed.is_a?(Hash)

        parsed
      rescue Psych::Exception
        :invalid_yaml
      end

      class << self
        private

        def build_config(raw, env:)
          AppConfig.new(
            tracker: build_tracker(raw["tracker"] || {}, raw, env: env),
            auth: build_auth(env: env),
            ai: build_ai(raw["ai"] || {}, env: env),
            security: build_security(raw["security"] || {}),
            push: build_push(raw["push"] || {})
          )
        end

        def build_tracker(trk, raw, env:)
          # ENV > tracker.* > legacy jira.* (empty-string-aware fallback)
          legacy_jira = raw["jira"].is_a?(Hash) ? raw["jira"] : {}

          tracker_base = trk["base_url"].to_s
          base_url = env.fetch("TASKMATE_JIRA_URL",
                               tracker_base.empty? ? legacy_jira["base_url"].to_s : tracker_base)

          tracker_project = trk["default_project"].to_s
          default_project = tracker_project.empty? ? legacy_jira["default_project"].to_s : tracker_project

          story_points = trk["story_points_field"] || legacy_jira["story_points_field"]

          TrackerConfig.new(
            base_url: base_url,
            default_project: default_project,
            story_points_field: story_points
          )
        end

        def build_auth(env:)
          JiraAuthConfig.new(
            email: env.fetch("TASKMATE_JIRA_EMAIL", ""),
            api_token: env.fetch("TASKMATE_JIRA_TOKEN", "")
          )
        end

        def build_ai(ai_raw, env:)
          provider = env.fetch("TASKMATE_AI_PROVIDER",
                               (ai_raw["provider"] || ai_raw["default_provider"] || "disabled").to_s)
          model    = env.fetch("TASKMATE_AI_MODEL",
                               (ai_raw["model"] || ai_raw["default_model"] || "").to_s)
          enabled  = ai_raw.fetch("enabled", true)

          AiConfig.new(
            provider: provider,
            model: model.empty? ? nil : model,
            enabled: enabled
          )
        end

        def build_security(sec)
          SecurityConfig.new(
            require_consent_for_ai: sec.fetch("require_consent_for_ai", true),
            require_confirm_for_push: sec.fetch("require_confirm_for_push", true),
            secret_detection: sec.fetch("secret_detection", true)
          )
        end

        def build_push(push)
          fields = Array(push["allowed_fields"])
          fields = DEFAULT_PUSH_FIELDS if fields.empty?
          PushConfig.new(allowed_fields: fields)
        end

        def deep_merge(base, override)
          base.merge(override) do |_key, old_val, new_val|
            if old_val.is_a?(Hash) && new_val.is_a?(Hash)
              deep_merge(old_val, new_val)
            else
              new_val
            end
          end
        end
      end
    end
  end
end
