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

      # Build from a typed AppConfig (Config::AppConfig value object).
      # ENV overrides are already applied by Config::Loader.load.
      def self.from_app_config(app_config)
        ai_cfg = app_config.ai

        unless ai_cfg.enabled
          require "taskmate/ai/providers/fake_provider"
          return Providers::FakeProvider.new(
            default_response: "AI is disabled in workspace.yml (ai.enabled: false)."
          )
        end

        if ai_cfg.provider.empty? || ai_cfg.provider == "disabled"
          require "taskmate/ai/providers/fake_provider"
          return Providers::FakeProvider.new(
            default_response: "AI is disabled. Set ai.provider in workspace.yml or TASKMATE_AI_PROVIDER env var."
          )
        end

        build(provider: ai_cfg.provider, model: ai_cfg.model)
      end

    end
  end
end
