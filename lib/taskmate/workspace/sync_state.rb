require "taskmate/workspace/canonical_hash"

module Taskmate
  module Workspace
    class SyncState
      STATES = %i[new_local clean local_changed jira_changed conflict].freeze

      def self.compute(issue_file:, jira_hash: nil)
        return :new_local if issue_file.new_local?

        current_hash = CanonicalHash.compute_for(issue_file)
        last_synced  = issue_file.last_synced_local_hash
        jira_source  = issue_file.jira_source_hash

        local_changed = current_hash != last_synced

        if local_changed
          if jira_hash && jira_hash != jira_source
            :conflict
          else
            :local_changed
          end
        elsif jira_hash && jira_hash != jira_source
          :jira_changed
        else
          :clean
        end
      end
    end
  end
end
