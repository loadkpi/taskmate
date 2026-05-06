require "taskmate/core/workspace_status"

module Taskmate
  module CLI
    module Commands
      class Workspace
        def initialize(options = {})
          @options = options
        end

        def status(workspace_path = Dir.pwd)
          result = Core::WorkspaceStatus.new(workspace_path: workspace_path).call
          render_status(result)
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

          if result.conflict_files.any?
            puts "\nUnresolved conflict files (#{result.conflict_files.size}):"
            result.conflict_files.each { |f| puts "  ! #{File.basename(f)}" }
          end
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
