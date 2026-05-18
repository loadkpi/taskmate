module Taskmate
  module Config
    class Validator
      VALID_AI_PROVIDERS = %w[openai anthropic ollama fake disabled].freeze
      BOOLEAN_SECURITY_KEYS = %w[require_consent_for_ai require_confirm_for_push secret_detection].freeze

      def self.validate!(raw)
        errs = errors(raw)
        raise Taskmate::ConfigError, "Config errors:\n  #{errs.join("\n  ")}" if errs.any?

        raw
      end

      def self.errors(raw)
        return ["root must be a Hash"] unless raw.is_a?(Hash)

        errs = []
        errs.concat(tracker_errors(raw["tracker"])) if raw.key?("tracker")
        errs.concat(ai_errors(raw["ai"])) if raw.key?("ai")
        errs.concat(security_errors(raw["security"])) if raw.key?("security")
        errs.concat(push_errors(raw["push"])) if raw.key?("push")
        errs
      end

      class << self
        private

        def tracker_errors(tracker)
          return ["tracker must be a Hash"] unless tracker.is_a?(Hash)

          []
        end

        def ai_errors(ai_cfg)
          return ["ai must be a Hash"] unless ai_cfg.is_a?(Hash)

          errs = []
          if ai_cfg.key?("provider")
            provider = ai_cfg["provider"].to_s
            unless VALID_AI_PROVIDERS.include?(provider)
              errs << "ai.provider '#{provider}' is invalid. Valid: #{VALID_AI_PROVIDERS.join(', ')}"
            end
          end
          errs
        end

        def security_errors(security)
          return ["security must be a Hash"] unless security.is_a?(Hash)

          BOOLEAN_SECURITY_KEYS.filter_map do |key|
            next unless security.key?(key)
            next if [true, false].include?(security[key])

            "security.#{key} must be true or false"
          end
        end

        def push_errors(push)
          return ["push must be a Hash"] unless push.is_a?(Hash)

          errs = []
          if push.key?("allowed_fields") && !push["allowed_fields"].is_a?(Array)
            errs << "push.allowed_fields must be an Array"
          end
          errs
        end
      end
    end
  end
end
