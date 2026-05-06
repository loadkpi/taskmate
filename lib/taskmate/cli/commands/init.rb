require "taskmate/workspace/initializer"

module Taskmate
  module CLI
    module Commands
      class Init
        def initialize(options = {})
          @options = options
        end

        def call(workspace_path = Dir.pwd)
          prompt = build_prompt

          initializer = Taskmate::Workspace::Initializer.new(
            workspace_path: workspace_path,
            interactive: !@options[:non_interactive],
            prompt: prompt
          )

          result = initializer.call
          render_result(result, workspace_path)
        end

        private

        def build_prompt
          return nil if @options[:non_interactive]

          require "tty-prompt"
          TTY::Prompt.new
        rescue LoadError
          raise Taskmate::ConfigError,
                "tty-prompt is required for interactive mode. Run: gem install tty-prompt"
        end

        def render_result(result, workspace_path)
          if result[:workspace_yml_exists]
            warn_line "workspace.yml already exists — skipping (not overwriting)."
          else
            ok_line "Created workspace.yml"
          end

          if result[:created_dirs].any?
            puts "\nCreated directories:"
            result[:created_dirs].each { |d| puts "  + #{d}" }
          end

          if result[:existing_dirs].any?
            puts "\nExisting directories (skipped):"
            result[:existing_dirs].each { |d| puts "  ~ #{d}" }
          end

          ok_line "\nCreated .taskmateignore" if result[:taskmateignore_created]

          case result[:skills_copied]
          when :copied
            ok_line "Copied built-in skills to skills/"
          when :already_present
            warn_line "Built-in skills already present in skills/ (skipped)"
          when :unavailable
            warn_line "No built-in skills bundled with this gem version"
          end

          puts "\nWorkspace initialized at #{workspace_path}"
          puts "Next: add your Jira credentials to ENV and run `taskmate doctor`"
        end

        def ok_line(msg)
          puts msg
        end

        def warn_line(msg)
          $stderr.puts msg
        end
      end
    end
  end
end
