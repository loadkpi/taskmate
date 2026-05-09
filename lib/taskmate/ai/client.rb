require "taskmate/ai/ai_port"

module Taskmate
  module AI
    class Client
      PROVIDERS = %w[openai anthropic ollama fake].freeze

      def self.build(provider:, model: nil, **)
        case provider.to_s
        when "openai"
          require "taskmate/ai/providers/openai_provider"
          Providers::OpenAiProvider.new(model: model, **)
        when "anthropic"
          require "taskmate/ai/providers/anthropic_provider"
          Providers::AnthropicProvider.new(model: model, **)
        when "ollama"
          require "taskmate/ai/providers/ollama_provider"
          Providers::OllamaProvider.new(model: model, **)
        when "fake"
          require "taskmate/ai/providers/fake_provider"
          Providers::FakeProvider.new(**)
        else
          raise ValidationError, "Unknown AI provider: '#{provider}'. Valid: #{PROVIDERS.join(', ')}"
        end
      end

      # Build from workspace.yml config hash
      def self.from_config(config)
        ai_config = config.is_a?(Hash) ? (config["ai"] || {}) : {}

        if ai_config["enabled"] == false
          require "taskmate/ai/providers/fake_provider"
          return Providers::FakeProvider.new(
            default_response: "AI is disabled in workspace.yml (ai.enabled: false)."
          )
        end

        # Support both canonical keys (from init) and legacy keys
        provider = ENV["TASKMATE_AI_PROVIDER"] ||
                   ai_config["provider"] ||
                   ai_config["default_provider"]
        provider = provider.to_s

        model = ENV["TASKMATE_AI_MODEL"] ||
                ai_config["model"] ||
                ai_config["default_model"]
        model = model.to_s

        if provider.empty? || provider == "disabled"
          require "taskmate/ai/providers/fake_provider"
          return Providers::FakeProvider.new(
            default_response: "AI is disabled. Set ai.provider in workspace.yml or TASKMATE_AI_PROVIDER env var."
          )
        end

        build(provider: provider, model: model.empty? ? nil : model)
      end
    end
  end
end
