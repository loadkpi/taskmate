require "taskmate/skills/loader"
require "taskmate/skills/validator"

module Taskmate
  module Skills
    class Registry
      def initialize(workspace_path:)
        @workspace_path = workspace_path
        @loader         = Loader.new(workspace_path: workspace_path)
        @validator      = Validator.new
      end

      def all
        skills_dir = File.join(@workspace_path, "skills")
        return [] unless File.directory?(skills_dir)

        Dir.glob(File.join(skills_dir, "*/skill.md")).filter_map do |path|
          @loader.load_from_path(path)
        rescue Loader::SkillLoadError
          nil
        end
      end

      def find(skill_id)
        @loader.load(skill_id)
      end

      def validate_all
        skills_dir = File.join(@workspace_path, "skills")
        paths      = File.directory?(skills_dir) ? Dir.glob(File.join(skills_dir, "*/skill.md")) : []

        paths.map do |path|
          begin
            skill  = @loader.load_from_path(path)
            result = @validator.validate(skill)
            { skill: skill, result: result }
          rescue Loader::SkillLoadError => e
            id = File.basename(File.dirname(path))
            broken_skill = ::Taskmate::Skills::Skill.new(id: id, path: path)
            broken_result = Validator::ValidationResult.new(
              valid: false, errors: ["Failed to load: #{e.message}"]
            )
            { skill: broken_skill, result: broken_result }
          end
        end
      end
    end
  end
end
