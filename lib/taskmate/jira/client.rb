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

      # Write methods — NO automatic retry
      def create_issue(payload)
        post("/#{API_VERSION}/issue", payload)
      end

      def update_issue(key, payload)
        put("/#{API_VERSION}/issue/#{key}", payload)
      end

      private

      def get(path, params = {})
        response = @conn.get(path, params)
        handle_response(response)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        raise Error, "Jira unreachable: #{e.message}"
      end

      # Write requests use a separate connection without retry middleware
      def post(path, body)
        response = write_conn.post(path) { |r| r.body = JSON.generate(body) }
        handle_write_response(response, "POST", path)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        raise JiraWriteError,
              "Jira write timed out or connection lost. " \
              "Check Jira for partial changes before retrying. Error: #{e.message}"
      end

      def put(path, body)
        response = write_conn.put(path) { |r| r.body = JSON.generate(body) }
        handle_write_response(response, "PUT", path)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        raise JiraWriteError,
              "Jira write timed out or connection lost. " \
              "Check Jira for partial changes before retrying. Error: #{e.message}"
      end

      def handle_write_response(response, method, path)
        case response.status
        when 200..204
          parse_json(response)
        when 400
          raise Error, "Jira validation error (400) for #{method} #{path}: #{response.body.to_s[0, 400]}"
        when 401, 403
          raise JiraAuthError, "Jira permission denied (#{response.status}). " \
                               "Check TASKMATE_JIRA_EMAIL and TASKMATE_JIRA_TOKEN."
        when 404
          raise JiraNotFoundError, "Jira resource not found (404) for #{method} #{path}."
        else
          raise JiraWriteError, "Jira write error (#{response.status}) for #{method} #{path}: #{response.body.to_s[0, 200]}"
        end
      end

      def write_conn
        @write_conn ||= build_write_connection
      end

      def build_write_connection
        credentials = Base64.strict_encode64("#{@email}:#{@api_token}")
        Faraday.new(url: @base_url) do |f|
          f.headers["Authorization"] = "Basic #{credentials}"
          f.headers["Content-Type"]  = "application/json"
          f.headers["Accept"]        = "application/json"
          f.adapter Faraday.default_adapter
          # No retry middleware for write operations
        end
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
