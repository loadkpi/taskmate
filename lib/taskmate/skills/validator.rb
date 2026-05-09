module Taskmate
  module Skills
    class Validator
      ValidationResult = Struct.new(:valid, :errors, keyword_init: true) do
        def valid?
          valid
        end
      end

      REQUIRED_FIELDS = %w[id version kind inputs outputs security].freeze
      REQUIRED_SECURITY_KEYS = %w[external_ai jira_write].freeze

      def validate(skill)
        errors = []

        REQUIRED_FIELDS.each do |field|
          val = skill.send(field.to_sym)
          errors << "Missing required field: #{field}" if val.nil? || val == "" || val == []
        end

        if skill.security.is_a?(Hash)
          REQUIRED_SECURITY_KEYS.each do |key|
            errors << "Missing security key: #{key}" unless skill.security.key?(key)
          end
        else
          errors << "Security section must be a mapping"
        end

        errors << "Prompt body is empty" if skill.prompt_body.nil? || skill.prompt_body.strip.empty?

        ValidationResult.new(valid: errors.empty?, errors: errors)
      end
    end
  end
end
