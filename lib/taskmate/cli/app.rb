require "thor"
require "taskmate/version"
require "taskmate/cli/commands/init"

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
        Commands::Init.new(options).call(Dir.pwd)
      end

      def self.handle_no_command_error(command, has_namespace = $thor_runner)
        $stderr.puts "Unknown command: #{command}\n\n"
        new.invoke(:help)
        exit 1
      end
    end
  end
end
