module Taskmate
  module Security
    class ConsentManager
      ConsentContext = Struct.new(
        :provider, :model, :files, :sections, :excluded_paths,
        keyword_init: true
      )

      def initialize(input: $stdin, output: $stdout, non_interactive: false)
        @input          = input
        @output         = output
        @non_interactive = non_interactive
      end

      # Returns :allow or :deny
      def request(context)
        return :deny if @non_interactive

        show_disclosure(context)
        prompt_user
      end

      private

      def show_disclosure(context)
        @output.puts "\n=== AI Call Disclosure ==="
        @output.puts "Provider : #{context.provider}"
        @output.puts "Model    : #{context.model}" if context.model

        if context.files&.any?
          @output.puts "\nFiles to be sent:"
          context.files.each { |f| @output.puts "  - #{f}" }
        end

        if context.sections&.any?
          @output.puts "\nSections included:"
          context.sections.each { |s| @output.puts "  - #{s}" }
        end

        if context.excluded_paths&.any?
          @output.puts "\nExcluded (via .taskmateignore):"
          context.excluded_paths.each { |p| @output.puts "  - #{p}" }
        end

        @output.puts
      end

      def prompt_user
        @output.print "Continue? [y/N] "
        @output.flush

        answer = @input.gets&.chomp.to_s.strip.downcase
        answer == "y" ? :allow : :deny
      end
    end

    # Test double — always allows or always denies
    class FakeConsentManager
      def initialize(response: :allow)
        @response = response
      end

      def request(_context)
        @response
      end
    end
  end
end
