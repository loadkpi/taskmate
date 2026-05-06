require "taskmate/jira/adf_to_markdown"
require "taskmate/workspace/issue_file"
require "taskmate/workspace/canonical_hash"

module Taskmate
  module Jira
    class IssueMapper
      # @param story_points_field [String, nil] custom field name e.g. "customfield_10016"
      def initialize(story_points_field: nil)
        @story_points_field = story_points_field
        @converter          = AdfToMarkdown.new
      end

      # Maps a raw Jira REST API issue hash to an IssueFile.
      # Returns [IssueFile, ConversionResult]
      def map(jira_issue)
        fields = jira_issue["fields"] || {}
        key    = jira_issue["key"]

        conversion = convert_description(fields["description"])
        body       = conversion.markdown

        fm = build_frontmatter(key, fields)
        issue = Workspace::IssueFile.build(frontmatter: fm, body: body)

        # Compute and store the Jira source hash
        issue.jira_source_hash = Workspace::CanonicalHash.compute_for(issue)

        [issue, conversion]
      end

      private

      def build_frontmatter(key, fields)
        {
          "key"          => key,
          "summary"      => fields["summary"].to_s,
          "status"       => extract_status(fields),
          "priority"     => extract_priority(fields),
          "issue_type"   => extract_issue_type(fields),
          "labels"       => Array(fields["labels"]),
          "components"   => extract_components(fields),
          "assignee"     => extract_user(fields["assignee"]),
          "reporter"     => extract_user(fields["reporter"]),
          "story_points" => extract_story_points(fields),
          "due_date"     => fields["duedate"]
        }.compact
      end

      def extract_status(fields)
        fields.dig("status", "name")
      end

      def extract_priority(fields)
        fields.dig("priority", "name")
      end

      def extract_issue_type(fields)
        fields.dig("issuetype", "name")
      end

      def extract_components(fields)
        Array(fields["components"]).map { |c| c["name"] }.compact
      end

      def extract_user(user_hash)
        return nil if user_hash.nil?

        {
          "account_id"   => user_hash["accountId"],
          "display_name" => user_hash["displayName"],
          "email"        => user_hash["emailAddress"]
        }.compact
      end

      def extract_story_points(fields)
        return nil if @story_points_field.nil?

        fields[@story_points_field]
      end

      def convert_description(adf)
        return AdfToMarkdown::ConversionResult.new(markdown: "", unsupported_nodes: []) if adf.nil?

        @converter.convert(adf)
      end
    end
  end
end
