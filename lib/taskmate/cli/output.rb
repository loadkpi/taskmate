module Taskmate
  module CLI
    # Terminal output helpers with optional color via pastel.
    # Falls back to plain text if pastel is unavailable or NO_COLOR is set.
    module Output
      def self.pastel
        @pastel ||= begin
          require "pastel"
          no_color = ENV["NO_COLOR"] || !$stdout.tty?
          Pastel.new(enabled: !no_color)
        rescue LoadError
          NullPastel.new
        end
      end

      def self.success(msg)
        $stdout.puts pastel.green(msg)
      end

      def self.error(msg)
        $stderr.puts pastel.red(msg)
      end

      def self.warn(msg)
        $stderr.puts pastel.yellow(msg)
      end

      def self.info(msg)
        $stdout.puts msg
      end

      def self.dim(msg)
        pastel.dim(msg)
      end

      # Simple spinner for long-running operations.
      # Falls back to a plain "..." message if tty-spinner is unavailable.
      def self.with_spinner(label)
        spinner = build_spinner(label)
        spinner.auto_spin
        result = yield
        spinner.success("done")
        result
      rescue StandardError
        spinner.error("failed")
        raise
      end

      def self.build_spinner(label)
        require "tty-spinner"
        TTY::Spinner.new("[:spinner] #{label}", format: :dots, output: $stderr)
      rescue LoadError
        NullSpinner.new(label)
      end

      # Fallback when pastel is not available
      class NullPastel
        def method_missing(_name, str, *) = str
        def respond_to_missing?(*) = true
      end

      # Fallback when tty-spinner is not available
      class NullSpinner
        def initialize(label)
          $stderr.print "#{label}... "
        end

        def auto_spin; end

        def success(_msg)
          $stderr.puts "done"
        end

        def error(_msg)
          $stderr.puts "failed"
        end
      end

      private_class_method :build_spinner
    end
  end
end
