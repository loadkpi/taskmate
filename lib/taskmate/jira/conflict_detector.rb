require "taskmate/jira/issue_mapper"
require "taskmate/workspace/canonical_hash"

module Taskmate
  module Jira
    class ConflictDetector
      ConflictResult = Struct.new(:status, :changed_fields, :local_hash, :jira_hash,
                                  keyword_init: true)

      def initialize(story_points_field: nil)
        @mapper = IssueMapper.new(story_points_field: story_points_field)
      end

      # Compare stored jira_source_hash with fresh Jira data hash.
      # Returns ConflictResult with status :no_conflict or :conflict
      def detect(local_issue:, jira_issue_raw:)
        fresh_issue, = @mapper.map(jira_issue_raw)
        current_jira_hash = fresh_issue.jira_source_hash

        stored_jira_hash = local_issue.jira_source_hash

        if stored_jira_hash == current_jira_hash
          ConflictResult.new(
            status: :no_conflict,
            changed_fields: [],
            local_hash: stored_jira_hash,
            jira_hash: current_jira_hash
          )
        else
          changed = find_changed_fields(local_issue, fresh_issue)
          ConflictResult.new(
            status: :conflict,
            changed_fields: changed,
            local_hash: stored_jira_hash,
            jira_hash: current_jira_hash
          )
        end
      end

      TRACKED_FIELDS = %w[summary status priority issue_type labels assignee due_date components story_points].freeze

      private

      def find_changed_fields(local_issue, jira_issue)
        changes = TRACKED_FIELDS.filter_map do |field|
          local_val = local_issue.frontmatter[field]
          jira_val  = jira_issue.frontmatter[field]
          field if local_val != jira_val
        end
        changes << "description" if local_issue.body.strip != jira_issue.body.strip
        changes
      end
    end
  end
end
