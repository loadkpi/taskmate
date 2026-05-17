require "taskmate/core/workspace_status"
require "taskmate/rendering/json_renderer"

module Taskmate
  module CLI
    module Commands
      class Workspace
        include Taskmate::Rendering::JsonRenderer
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
          if all_empty?(result)
            puts "Workspace is empty — no issues found."
            return
          end

          print_section("Local changes (#{result.local_changed.size})", result.local_changed, "M")
          print_section("New local (#{result.new_local.size})", result.new_local, "+")
          print_section("Clean (#{result.clean.size})", result.clean, " ")

          return unless result.conflict_files.any?

          puts "\nUnresolved conflict files (#{result.conflict_files.size}):"
          result.conflict_files.each { |f| puts "  ! #{File.basename(f)}" }
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

        def print_section(header, issues, prefix)
          return if issues.empty?

          puts "\n#{header}:"
          issues.each do |issue|
            key  = issue.key || "(new)"
            summ = issue.summary.to_s[0, 60]
            puts "  #{prefix} #{key.ljust(12)} #{summ}"
          end
        end

        def all_empty?(result)
          result.clean.empty? && result.local_changed.empty? &&
            result.new_local.empty? && result.conflict_files.empty?
        end
      end
    end
  end
end
