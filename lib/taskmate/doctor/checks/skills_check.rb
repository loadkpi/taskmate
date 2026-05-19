require "taskmate/doctor/check"
require "taskmate/skills/loader"
require "taskmate/skills/validator"

module Taskmate
  module Doctor
    module Checks
      class SkillsCheck < Check
        EXPECTED_SKILLS = %w[create-task improve-task review-task].freeze

        BUILTINS_DIR = File.expand_path("../../skills/builtins", __dir__)

        def initialize(workspace_path:)
          super(name: "built-in skills", description: "Built-in skills are present and valid")
          @workspace_path = workspace_path
        end

        def run
          skills_dir = File.join(@workspace_path, "skills")
          return fail!("skills/ directory missing. Run `taskmate init`.") unless Dir.exist?(skills_dir)

          # If gem doesn't bundle skills yet (added in M5-T5), skip gracefully
          unless Dir.exist?(BUILTINS_DIR)
            return skip!("Built-in skills not bundled in this gem version (available in a future release)")
          end

          missing = EXPECTED_SKILLS.reject do |skill|
            File.exist?(File.join(skills_dir, skill, "skill.md"))
          end

          unless missing.empty?
            return fail!("Missing built-in skills: #{missing.join(', ')}. Run `taskmate init` to copy them.")
          end

          invalid = invalid_skills
          if invalid.empty?
            ok!("All built-in skills present and valid")
          else
            fail!("Invalid built-in skills: #{invalid.join(', ')}")
          end
        end

        private

        def invalid_skills
          loader = Skills::Loader.new(workspace_path: @workspace_path)
          validator = Skills::Validator.new

          EXPECTED_SKILLS.filter_map do |skill_id|
            result = validator.validate(loader.load(skill_id))
            skill_id unless result.valid?
          rescue Skills::Loader::SkillLoadError
            skill_id
          end
        end
      end
    end
  end
end
