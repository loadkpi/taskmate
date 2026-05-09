module Taskmate
  module Security
    class ActionGate
      ActionPlan = Struct.new(:field_changes, :warnings, keyword_init: true) do
        def self.build(field_changes: [], warnings: [])
          new(field_changes: field_changes, warnings: warnings)
        end
      end

      FieldChange = Struct.new(:field, :from, :to, keyword_init: true)

      def initialize(input: $stdin, output: $stdout, non_interactive: false)
        @input           = input
        @output          = output
        @non_interactive = non_interactive
      end

      # Returns :allow or :deny
      def confirm(action_plan, preamble: nil)
        return :deny if @non_interactive

        @output.puts preamble if preamble
        show_plan(action_plan)
        prompt_user
      end

      private

      def show_plan(plan)
        @output.puts "\n=== Proposed Jira Changes ==="

        if plan.field_changes&.any?
          @output.puts "\nField changes:"
          plan.field_changes.each do |change|
            @output.puts "  #{change.field}:"
            @output.puts "    from: #{change.from.inspect}"
            @output.puts "    to:   #{change.to.inspect}"
          end
        else
          @output.puts "\n(no field changes)"
        end

        if plan.warnings&.any?
          @output.puts "\nWarnings:"
          plan.warnings.each { |w| @output.puts "  ! #{w}" }
        end

        @output.puts
      end

      def prompt_user
        @output.print "Apply? [y/N] "
        @output.flush

        answer = @input.gets&.chomp.to_s.strip.downcase
        answer == "y" ? :allow : :deny
      end
    end
  end
end
