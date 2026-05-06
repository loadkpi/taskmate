require "thor"
require "taskmate/version"
require "taskmate/cli/commands/init"
require "taskmate/cli/commands/doctor"
require "taskmate/cli/commands/workspace"
require "taskmate/cli/commands/show"
require "taskmate/cli/commands/diff"
require "taskmate/cli/commands/pull"

module Taskmate
  module CLI
    class App < Thor
      def self.exit_on_failure?
        true
      end

      default_task :help

      desc "version", "Print Taskmate version"
      def version
        puts Taskmate::VERSION
      end

      desc "init", "Initialize a Taskmate workspace in the current directory"
      option :non_interactive, type: :boolean, default: false,
                               desc: "Use defaults without interactive prompts (for CI)"
      def init
        with_error_handling { Commands::Init.new(options).call(Dir.pwd) }
      end

      desc "doctor", "Run workspace health checks"
      def doctor
        with_error_handling { Commands::Doctor.new(options).call(Dir.pwd) }
      end

      desc "show KEY", "Display issue details"
      option :metadata, type: :boolean, default: false, desc: "Show all frontmatter fields"
      option :format,   type: :string,  default: "text", desc: "Output format: text or json"
      def show(key)
        with_error_handling { Commands::Show.new(options).call(key, Dir.pwd) }
      end

      desc "diff KEY", "Show diff vs last pulled version"
      option :format, type: :string, default: "text", desc: "Output format: text or json"
      def diff(key)
        with_error_handling { Commands::Diff.new(options).call(key, Dir.pwd) }
      end

      desc "pull [KEY]", "Pull issue(s) from Jira"
      option :jql,    type: :string,  desc: "JQL query to pull multiple issues"
      option :limit,  type: :numeric, default: 50, desc: "Max issues to pull (JQL mode)"
      option :format, type: :string,  default: "text", desc: "Output format: text or json"
      def pull(key = nil)
        with_error_handling { Commands::Pull.new(options).call(key, Dir.pwd) }
      end

      desc "workspace SUBCOMMAND", "Workspace commands"
      subcommand "workspace", Class.new(Thor) {
        desc "status", "Show sync status of all local issues"
        define_method(:status) do
          begin
            Commands::Workspace.new(options).status(Dir.pwd)
          rescue Taskmate::IssueNotFoundError => e
            warn "Error: #{e.message}"; exit 1
          rescue Taskmate::ConsentDeniedError
            exit 0
          rescue Taskmate::ConflictError => e
            warn "Conflict: #{e.message}"; exit 3
          rescue Taskmate::ValidationError => e
            warn "Validation error: #{e.message}"; exit 2
          rescue Taskmate::JiraAuthError => e
            warn "Authentication failed: #{e.message}\nCheck TASKMATE_JIRA_EMAIL and TASKMATE_JIRA_TOKEN."; exit 4
          rescue Taskmate::Error => e
            warn "Error: #{e.message}"; exit 1
          end
        end
      }

      def self.handle_no_command_error(command, _has_namespace = $thor_runner)
        warn "Unknown command: #{command}\n\n"
        new.invoke(:help)
        exit 1
      end

      private

      def with_error_handling
        yield
      rescue Taskmate::IssueNotFoundError => e
        warn "Error: #{e.message}"
        exit 1
      rescue Taskmate::ConsentDeniedError
        # User cancelled — normal flow
        exit 0
      rescue Taskmate::ConflictError => e
        warn "Conflict: #{e.message}"
        exit 3
      rescue Taskmate::ValidationError => e
        warn "Validation error: #{e.message}"
        exit 2
      rescue Taskmate::JiraAuthError => e
        warn "Authentication failed: #{e.message}\nCheck TASKMATE_JIRA_EMAIL and TASKMATE_JIRA_TOKEN."
        exit 4
      rescue Taskmate::Error => e
        warn "Error: #{e.message}"
        exit 1
      end
    end
  end
end
