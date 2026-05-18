require "taskmate/core/validate_issue"
require "taskmate/rendering/json_renderer"
require "taskmate/rendering/text_renderer"

module Taskmate
  module CLI
    module Commands
      class Validate
        include Taskmate::Rendering::JsonRenderer
        include Taskmate::Rendering::TextRenderer

        VALID_FORMATS = %w[text json].freeze

        def initialize(options = {})
          @options = options
        end

        def call(key, workspace_path = Dir.pwd)
          fmt = @options[:format].to_s
          unless VALID_FORMATS.include?(fmt)
            raise Taskmate::ValidationError, "Invalid format '#{fmt}'. Valid: #{VALID_FORMATS.join(', ')}"
          end

          result = Core::ValidateIssue.new(workspace_path: workspace_path).call(key)

          if fmt == "json"
            render_json(result)
          else
            render_text(result)
          end

          exit 2 unless result.valid?
        end

        private

        def render_text(result)
          render_validate_text(result)
        end

        def render_json(result)
          super(
            "key" => result.issue_file.key,
            "valid" => result.valid?,
            "errors" => result.errors.map do |e|
              { "feature" => e.feature, "line" => e.line_number, "message" => e.message }
            end
          )
        end
      end
    end
  end
end
