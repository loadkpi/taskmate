require "taskmate/workspace/issue_file"
require "taskmate/workspace/sync_state"

module Taskmate
  module Core
    class WorkspaceStatus
      StatusResult = Struct.new(:clean, :local_changed, :new_local, :conflict_files, keyword_init: true)

      def initialize(workspace_path:)
        @workspace_path = workspace_path
      end

      def call
        clean          = []
        local_changed  = []
        new_local      = []
        conflict_files = []

        scan_issues(clean, local_changed)
        scan_new_issues(new_local, clean, local_changed)
        scan_conflict_files(conflict_files)

        StatusResult.new(
          clean: clean,
          local_changed: local_changed,
          new_local: new_local,
          conflict_files: conflict_files
        )
      end

      private

      def scan_issues(clean, local_changed)
        Dir.glob(File.join(@workspace_path, "issues", "*.md")).each do |path|
          issue = Workspace::IssueFile.read(path)
          state = Workspace::SyncState.compute(issue_file: issue)

          case state
          when :clean          then clean << issue
          when :local_changed  then local_changed << issue
          end
        rescue Taskmate::InvalidFrontmatterError
          # Skip files with invalid frontmatter
        end
      end

      def scan_new_issues(new_local, clean, local_changed)
        Dir.glob(File.join(@workspace_path, "issues", "new", "*.md")).each do |path|
          issue = Workspace::IssueFile.read(path)
          if issue.new_local?
            new_local << issue
          else
            # Keyed file mistakenly placed in new/ — classify by sync state
            state = Workspace::SyncState.compute(issue_file: issue)
            case state
            when :clean         then clean << issue
            when :local_changed then local_changed << issue
            else                     new_local << issue
            end
          end
        rescue Taskmate::InvalidFrontmatterError
          # Skip
        end
      end

      def scan_conflict_files(conflict_files)
        pattern = File.join(@workspace_path, "issues", "conflicts", "*.md")
        Dir.glob(pattern).each do |path|
          conflict_files << path
        end
      end
    end
  end
end
