require "json"
require "fileutils"

module Taskmate
  module Jira
    class AdfBackup
      # Save ADF JSON backup when unsupported nodes were detected.
      # backup_path: issues/.jira/<KEY>.description.adf.json
      #
      # @return [String, nil] path to backup file, or nil if not saved
      def self.save(key:, adf:, workspace_path:, unsupported_nodes: [])
        return nil if unsupported_nodes.empty?

        dir = File.join(workspace_path, "issues", ".jira")
        FileUtils.mkdir_p(dir)

        path = File.join(dir, "#{key}.description.adf.json")
        File.write(path, JSON.pretty_generate(adf || {}), encoding: "utf-8")
        path
      end

      def self.path_for(key:, workspace_path:)
        File.join(workspace_path, "issues", ".jira", "#{key}.description.adf.json")
      end
    end
  end
end
