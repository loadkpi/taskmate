require "faraday"
require "faraday/retry"
require "json"
require "base64"

module Taskmate
  module Jira
    class Client
      DEFAULT_MAX_RETRIES = 3
      API_VERSION         = "rest/api/3"

      def initialize(base_url:, email:, api_token:, max_retries: DEFAULT_MAX_RETRIES)
        @base_url = base_url.to_s.chomp("/")
        @email     = email
        @api_token = api_token
        @conn      = build_connection(max_retries)
      end

      def get_project(key)
        get("/#{API_VERSION}/project/#{key}")
      end

      def find_issue(key)
        get("/#{API_VERSION}/issue/#{key}")
      end

      def search_issues(jql:, limit: 50)
        response = get("/#{API_VERSION}/search", jql: jql, maxResults: limit, fields: "*all")
        Array(response["issues"])
      end

      private

      def get(path, params = {})
        response = @conn.get(path, params)
        handle_response(response)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        raise Error, "Jira unreachable: #{e.message}"
      end

      def handle_response(response)
        case response.status
        when 200..299
          parse_json(response)
        when 401, 403
          raise JiraAuthError, "Jira authentication failed (#{response.status}). " \
                               "Check TASKMATE_JIRA_EMAIL and TASKMATE_JIRA_TOKEN."
        when 404
          raise JiraNotFoundError, "Jira resource not found (404)."
        when 429
          raise JiraRateLimitError, "Jira rate limit exceeded. Retry later."
        else
          raise Error, "Jira API error (#{response.status}): #{response.body.to_s[0, 200]}"
        end
      end

      def parse_json(response)
        return {} if response.body.nil? || response.body.empty?

        JSON.parse(response.body)
      rescue JSON::ParserError => e
        raise Error, "Jira returned invalid JSON: #{e.message}"
      end

      def build_connection(max_retries)
        credentials = Base64.strict_encode64("#{@email}:#{@api_token}")

        Faraday.new(url: @base_url) do |f|
          f.headers["Authorization"] = "Basic #{credentials}"
          f.headers["Content-Type"]  = "application/json"
          f.headers["Accept"]        = "application/json"

          f.request :retry,
            max:                 max_retries,
            interval:            0.5,
            interval_randomness: 0.5,
            backoff_factor:      2,
            retry_statuses:      [429, 500, 502, 503, 504]

          f.adapter Faraday.default_adapter
        end
      end
    end
  end
end
