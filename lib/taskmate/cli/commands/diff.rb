require "taskmate/core/diff_issue"
require "taskmate/rendering/json_renderer"
require "taskmate/rendering/text_renderer"

module Taskmate
  module CLI
    module Commands
      class Diff
        include Taskmate::Rendering::JsonRenderer
        include Taskmate::Rendering::TextRenderer

        def initialize(options = {})
          @options = options
        end

        VALID_FORMATS = %w[text json].freeze

        def call(key, workspace_path = Dir.pwd)
          fmt_str = @options[:format].to_s
          unless VALID_FORMATS.include?(fmt_str)
            raise Taskmate::ValidationError, "Invalid format '#{fmt_str}'. Valid options: #{VALID_FORMATS.join(', ')}"
          end

          diff = Core::DiffIssue.new(workspace_path: workspace_path).call(key)

          if fmt_str == "json"
            render_json(diff)
          else
            render_text(diff, key)
          end
        end

        private

        def render_text(diff, _key)
          render_diff_text(diff)
        end

        def render_json(diff)
          super(
            "issue_key" => diff.issue_key,
            "empty" => diff.empty?,
            "hunks" => diff.hunks
          )
        end
      end
    end
  end
end
