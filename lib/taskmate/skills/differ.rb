require "taskmate/skills/loader"
require "taskmate/workspace/diff"

module Taskmate
  module Skills
    class Differ
      BUILTINS_DIR = File.expand_path("../skills/builtins", __dir__)

      DiffResult = Struct.new(:status, :diff_text, keyword_init: true)

      def initialize(workspace_path:)
        @workspace_path = workspace_path
        @loader         = Loader.new(workspace_path: workspace_path)
      end

      def diff(skill_id)
        builtin_path = File.join(BUILTINS_DIR, skill_id, "skill.md")

        return DiffResult.new(status: :custom, diff_text: nil) unless File.exist?(builtin_path)

        local_path = File.join(@workspace_path, "skills", skill_id, "skill.md")
        return DiffResult.new(status: :custom, diff_text: nil) unless File.exist?(local_path)

        local_content   = File.read(local_path, encoding: "utf-8")
        builtin_content = File.read(builtin_path, encoding: "utf-8")

        if local_content == builtin_content
          DiffResult.new(status: :no_changes, diff_text: nil)
        else
          d = Workspace::Diff.new(
            issue_key: skill_id,
            original: builtin_content,
            modified: local_content
          )
          # Build skill-specific headers (Workspace::Diff always uses issues/ prefix)
          skill_path = "skills/#{skill_id}/skill.md"
          header     = "--- a/#{skill_path}\n+++ b/#{skill_path}\n"
          diff_text  = d.empty? ? "(no changes)" : header + d.hunks.join("\n")
          DiffResult.new(status: :modified, diff_text: diff_text)
        end
      end
    end
  end
end
