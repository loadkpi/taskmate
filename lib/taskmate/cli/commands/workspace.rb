require "taskmate/core/workspace_status"
require "taskmate/rendering/json_renderer"
require "taskmate/rendering/text_renderer"

module Taskmate
  module CLI
    module Commands
      class Workspace
        include Taskmate::Rendering::JsonRenderer
        include Taskmate::Rendering::TextRenderer

        VALID_FORMATS = %w[text json].freeze

        def initialize(options = {})
          @options = options
        end

        def status(workspace_path = Dir.pwd)
          fmt = @options[:format].to_s
          fmt = "text" if fmt.empty?
          unless VALID_FORMATS.include?(fmt)
            raise Taskmate::ValidationError, "Invalid format '#{fmt}'. Valid: #{VALID_FORMATS.join(', ')}"
          end

          result = Core::WorkspaceStatus.new(workspace_path: workspace_path).call

          if fmt == "json"
            render_status_json(result)
          else
            render_status(result)
          end
        end

        private

        def render_status(result)
          render_workspace_status_text(result)
        end

        def render_status_json(result)
          render_json(
            "local_changed" => result.local_changed.map { |i| issue_summary(i) },
            "new_local" => result.new_local.map { |i| issue_summary(i) },
            "clean" => result.clean.map { |i| issue_summary(i) },
            "conflict_files" => result.conflict_files.map { |f| File.basename(f) }
          )
        end

        def issue_summary(issue)
          { "key" => issue.key, "summary" => issue.summary }
        end
      end
    end
  end
end
