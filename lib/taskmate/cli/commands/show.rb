require "taskmate/core/show_issue"
require "taskmate/rendering/json_renderer"
require "taskmate/rendering/text_renderer"

module Taskmate
  module CLI
    module Commands
      class Show
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

          format   = fmt_str.to_sym
          metadata = @options[:metadata] || false
          result   = Core::ShowIssue.new(workspace_path: workspace_path).call(key, format: format, _metadata: metadata)
          render(result, metadata)
        end

        private

        def render(result, metadata)
          issue = result.issue_file

          if result.format == :json
            render_json(issue, metadata)
          else
            render_text(issue, metadata)
          end
        end

        def render_text(issue, metadata)
          render_show_text(issue, metadata: metadata)
        end

        def render_json(issue, metadata)
          data = if metadata
                   issue.frontmatter.merge(
                     "body" => issue.body,
                     "assignee" => serialize_assignee(issue.assignee)
                   )
                 else
                   {
                     "key" => issue.key,
                     "summary" => issue.summary,
                     "status" => issue.status,
                     "priority" => issue.priority,
                     "assignee" => serialize_assignee(issue.assignee),
                     "labels" => issue.labels,
                     "body" => issue.body
                   }
                 end
          super(data)
        end

        def serialize_assignee(assignee)
          return nil if assignee.nil?

          { "account_id" => assignee.account_id, "display_name" => assignee.display_name, "email" => assignee.email }
        end
      end
    end
  end
end
