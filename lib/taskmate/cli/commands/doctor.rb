require "taskmate/doctor/runner"

module Taskmate
  module CLI
    module Commands
      class Doctor
        STATUS_ICONS = {
          ok: "OK  ",
          fail: "FAIL",
          skip: "SKIP"
        }.freeze

        def initialize(options = {})
          @options = options
        end

        def call(workspace_path = Dir.pwd)
          runner = Taskmate::Doctor::Runner.new(workspace_path: workspace_path)
          checks = runner.run

          render_results(checks)

          has_failures = checks.any? { |c| c.status == :fail }
          exit 1 if has_failures
        end

        private

        def render_results(checks)
          puts "\nTaskmate doctor\n#{"-" * 40}"

          checks.each do |check|
            icon = STATUS_ICONS[check.status]
            line = "[ #{icon} ] #{check.description}"
            line += " — #{check.message}" if check.message
            puts line
          end

          puts "-" * 40
          ok_count   = checks.count { |c| c.status == :ok }
          fail_count = checks.count { |c| c.status == :fail }
          skip_count = checks.count { |c| c.status == :skip }
          puts "#{ok_count} ok, #{fail_count} failed, #{skip_count} skipped\n\n"
        end
      end
    end
  end
end
