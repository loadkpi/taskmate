require "faraday"
require "json"
require "taskmate/ai/ai_port"

module Taskmate
  module AI
    module Providers
      class OpenAiProvider
        include AiPort

        BASE_URL         = "https://api.openai.com".freeze
        DEFAULT_MODEL    = "gpt-4o".freeze
        CONNECT_TIMEOUT  = 10   # seconds
        READ_TIMEOUT     = 120  # AI inference can take time

        def initialize(model: nil, api_key: nil)
          @model   = model || DEFAULT_MODEL
          @api_key = api_key || ENV.fetch("TASKMATE_OPENAI_API_KEY") do
            raise AiAuthError, "OpenAI API key not set. Export TASKMATE_OPENAI_API_KEY."
          end
          @conn = build_connection
        end

        def complete(prompt:, skill_id:, model: nil) # rubocop:disable Lint/UnusedMethodArgument
          used_model = model || @model
          payload    = {
            model: used_model,
            messages: [{ role: "user", content: prompt }]
          }

          response = @conn.post("/v1/chat/completions") do |req|
            req.body = JSON.generate(payload)
          end

          handle_response(response)
        rescue Faraday::ConnectionFailed => e
          raise Error, "OpenAI unreachable: #{e.message}"
        rescue Faraday::TimeoutError => e
          raise Error, "OpenAI request timed out: #{e.message}"
        end

        private

        def build_connection
          Faraday.new(url: BASE_URL) do |f|
            f.headers["Authorization"] = "Bearer #{@api_key}"
            f.headers["Content-Type"]  = "application/json"
            f.headers["Accept"]        = "application/json"
            f.options.open_timeout     = CONNECT_TIMEOUT
            f.options.timeout          = READ_TIMEOUT
            f.adapter Faraday.default_adapter
          end
        end

        def handle_response(response)
          case response.status
          when 200..299
            data = JSON.parse(response.body)
            data.dig("choices", 0, "message", "content").to_s
          when 401, 403
            raise AiAuthError, "OpenAI authentication failed. Check TASKMATE_OPENAI_API_KEY."
          when 429
            raise Error, "OpenAI rate limit exceeded. Retry later."
          else
            raise Error, "OpenAI API error (#{response.status}): #{response.body.to_s[0, 200]}"
          end
        rescue JSON::ParserError => e
          raise Error, "OpenAI returned invalid JSON: #{e.message}"
        end
      end
    end
  end
end
