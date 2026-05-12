require "faraday"
require "json"
require "taskmate/ai/ai_port"

module Taskmate
  module AI
    module Providers
      class OllamaProvider
        include AiPort

        DEFAULT_BASE_URL = "http://localhost:11434".freeze
        DEFAULT_MODEL    = "llama3".freeze
        CONNECT_TIMEOUT  = 10   # seconds
        READ_TIMEOUT     = 120  # local inference can be slow

        def initialize(model: nil, base_url: nil)
          @model    = model || DEFAULT_MODEL
          @base_url = base_url || ENV.fetch("TASKMATE_OLLAMA_URL", DEFAULT_BASE_URL)
          @conn     = build_connection
        end

        def complete(prompt:, skill_id:, model: nil) # rubocop:disable Lint/UnusedMethodArgument
          used_model = model || @model
          payload    = {
            model: used_model,
            prompt: prompt,
            stream: false
          }

          response = @conn.post("/api/generate") do |req|
            req.body = JSON.generate(payload)
          end

          handle_response(response)
        rescue Faraday::ConnectionFailed => e
          raise Error, "Ollama not reachable at #{@base_url}. Is Ollama running? (#{e.message})"
        rescue Faraday::TimeoutError => e
          raise Error, "Ollama request timed out: #{e.message}"
        end

        private

        def build_connection
          Faraday.new(url: @base_url) do |f|
            f.headers["Content-Type"] = "application/json"
            f.headers["Accept"]       = "application/json"
            f.options.open_timeout    = CONNECT_TIMEOUT
            f.options.timeout         = READ_TIMEOUT
            f.adapter Faraday.default_adapter
          end
        end

        def handle_response(response)
          case response.status
          when 200..299
            data = JSON.parse(response.body)
            data["response"].to_s
          else
            raise Error, "Ollama error (#{response.status}): #{response.body.to_s[0, 200]}"
          end
        rescue JSON::ParserError => e
          raise Error, "Ollama returned invalid JSON: #{e.message}"
        end
      end
    end
  end
end
