require "taskmate/skills/skill"
require "taskmate/workspace/frontmatter_file"

module Taskmate
  module Skills
    class Loader
      class SkillLoadError < Error; end

      def initialize(workspace_path:)
        @workspace_path = workspace_path
      end

      def load(skill_id)
        path = skill_path(skill_id)
        raise SkillLoadError, "Skill not found: #{skill_id} (expected at #{path})" unless File.exist?(path)

        parse(path)
      end

      def load_from_path(path)
        raise SkillLoadError, "Skill file not found: #{path}" unless File.exist?(path)

        parse(path)
      end

      private

      def skill_path(skill_id)
        File.join(@workspace_path, "skills", skill_id, "skill.md")
      end

      def parse(path)
        content = File.read(path, encoding: "utf-8")
        ff = begin
          Workspace::FrontmatterFile.parse(content)
        rescue InvalidFrontmatterError => e
          raise SkillLoadError, "Invalid skill file #{path}: #{e.message}"
        end

        fm = ff.frontmatter
        Skill.new(
          id:              fm["id"],
          version:         fm["version"],
          kind:            fm["kind"],
          description:     fm["description"],
          requires_ai:     fm.fetch("requires_ai", true),
          inputs:          Array(fm["inputs"]),
          outputs:         Array(fm["outputs"]),
          security:        fm["security"] || {},
          source:          fm["source"],
          builtin_version: fm["builtin_version"],
          source_hash:     fm["source_hash"],
          prompt_body:     ff.body.strip,
          path:            path
        )
      end
    end
  end
end
