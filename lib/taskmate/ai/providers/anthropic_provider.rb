require "faraday"
require "json"
require "taskmate/ai/ai_port"

module Taskmate
  module AI
    module Providers
      class AnthropicProvider
        include AiPort

        BASE_URL         = "https://api.anthropic.com".freeze
        API_VERSION      = "2023-06-01".freeze
        DEFAULT_MODEL    = "claude-sonnet-4-6".freeze
        MAX_TOKENS       = 4096
        CONNECT_TIMEOUT  = 10   # seconds
        READ_TIMEOUT     = 120  # AI inference can take time

        def initialize(model: nil, api_key: nil)
          @model   = model || DEFAULT_MODEL
          @api_key = api_key || ENV.fetch("TASKMATE_ANTHROPIC_API_KEY") do
            raise AiAuthError, "Anthropic API key not set. Export TASKMATE_ANTHROPIC_API_KEY."
          end
          @conn = build_connection
        end

        def complete(prompt:, skill_id:, model: nil) # rubocop:disable Lint/UnusedMethodArgument
          used_model = model || @model
          payload    = {
            model: used_model,
            max_tokens: MAX_TOKENS,
            messages: [{ role: "user", content: prompt }]
          }

          response = @conn.post("/v1/messages") do |req|
            req.body = JSON.generate(payload)
          end

          handle_response(response)
        rescue Faraday::ConnectionFailed => e
          raise AiProviderError, "Anthropic unreachable: #{e.message}"
        rescue Faraday::TimeoutError => e
          raise AiProviderError, "Anthropic request timed out: #{e.message}"
        end

        private

        def build_connection
          Faraday.new(url: BASE_URL) do |f|
            f.headers["x-api-key"]          = @api_key
            f.headers["anthropic-version"]  = API_VERSION
            f.headers["Content-Type"]       = "application/json"
            f.headers["Accept"]             = "application/json"
            f.options.open_timeout          = CONNECT_TIMEOUT
            f.options.timeout               = READ_TIMEOUT
            f.adapter Faraday.default_adapter
          end
        end

        def handle_response(response)
          case response.status
          when 200..299
            data = JSON.parse(response.body)
            data.dig("content", 0, "text").to_s
          when 401, 403
            raise AiAuthError, "Anthropic authentication failed. Check TASKMATE_ANTHROPIC_API_KEY."
          when 429
            raise AiProviderError, "Anthropic rate limit exceeded. Retry later."
          else
            raise AiProviderError, "Anthropic API error (#{response.status}): #{response.body.to_s[0, 200]}"
          end
        rescue JSON::ParserError => e
          raise AiProviderError, "Anthropic returned invalid JSON: #{e.message}"
        end
      end
    end
  end
end
