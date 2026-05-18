require "taskmate/cli/output"

module Taskmate
  module Rendering
    # Formats a unified diff string with colored +/- lines.
    # Uses pastel for color with graceful degradation via CLI::Output.pastel.
    class DiffRenderer
      def self.render(diff_text, pastel: CLI::Output.pastel)
        diff_text.to_s.each_line.map { |line| colorize_line(line, pastel) }.join
      end

      class << self
        private

        def colorize_line(line, pastel)
          if line.start_with?("+") && !line.start_with?("+++")
            pastel.green(line.chomp) + "\n"
          elsif line.start_with?("-") && !line.start_with?("---")
            pastel.red(line.chomp) + "\n"
          else
            line
          end
        end
      end
    end
  end
end
