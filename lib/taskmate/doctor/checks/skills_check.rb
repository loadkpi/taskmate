require "taskmate/doctor/check"

module Taskmate
  module Doctor
    module Checks
      class SkillsCheck < Check
        EXPECTED_SKILLS = %w[create-task improve-task review-task].freeze

        def initialize(workspace_path:)
          super(name: "built-in skills", description: "Built-in skills are present and valid")
          @workspace_path = workspace_path
        end

        def run
          skills_dir = File.join(@workspace_path, "skills")
          return fail!("skills/ directory missing. Run `taskmate init`.") unless Dir.exist?(skills_dir)

          # If gem doesn't bundle skills yet (added in M5-T5), skip gracefully
          builtins_dir = File.join(File.dirname(__FILE__), "..", "..", "skills", "builtins")
          unless Dir.exist?(builtins_dir)
            return skip!("Built-in skills not bundled in this gem version (available in a future release)")
          end

          missing = EXPECTED_SKILLS.reject do |skill|
            skill_file = File.join(skills_dir, skill, "skill.md")
            File.exist?(skill_file)
          end

          if missing.empty?
            ok!("All built-in skills present")
          else
            fail!("Missing built-in skills: #{missing.join(', ')}. Run `taskmate init` to copy them.")
          end
        end
      end
    end
  end
end
