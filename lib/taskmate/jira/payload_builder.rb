require "taskmate/jira/markdown_to_adf"
require "taskmate/jira/adf_to_markdown"

module Taskmate
  module Jira
    class PayloadBuilder
      # push_config: from workspace.yml push section (hash of allowed fields)
      def initialize(push_config: {}, story_points_field: nil, default_project: nil)
        @push_config        = push_config || {}
        @story_points_field = story_points_field
        @default_project    = default_project.to_s
        @converter          = MarkdownToAdf.new
        @back_converter     = AdfToMarkdown.new
      end

      # Build payload for creating a new issue (POST /rest/api/3/issue)
      def build_create(issue_file)
        fields = {}
        fields["project"] = { "key" => @default_project } unless @default_project.empty?
        fields["summary"] = issue_file.summary if allow?("summary")
        fields["issuetype"] = { "name" => issue_file.issue_type } if issue_file.issue_type
        fields["description"] = adf(issue_file.body) if allow?("description")
        fields["labels"] = issue_file.labels if allow?("labels") && issue_file.labels.any?
        fields["components"] = components_payload(issue_file) if allow?("components") && issue_file.components.any?
        fields["priority"] = { "name" => issue_file.priority } if allow?("priority") && issue_file.priority

        { "fields" => fields }
      end

      # Build payload for updating an existing issue (PUT /rest/api/3/issue/{key})
      # Only includes fields that differ from the Jira version.
      def build_update(issue_file, jira_fields: {})
        fields = {}
        maybe_update_summary(fields, issue_file, jira_fields)
        maybe_update_description(fields, issue_file, jira_fields)
        maybe_update_labels(fields, issue_file, jira_fields)
        maybe_update_components(fields, issue_file, jira_fields)
        maybe_update_priority(fields, issue_file, jira_fields)
        { "fields" => fields }
      end

      private

      def maybe_update_summary(fields, issue_file, jira_fields)
        return unless allow?("summary") && issue_file.summary != jira_fields["summary"]

        fields["summary"] = issue_file.summary
      end

      def maybe_update_description(fields, issue_file, jira_fields)
        return unless allow?("description")

        local_body = issue_file.body.strip
        jira_body  = @back_converter.convert(jira_fields["description"]).markdown.strip
        return if local_body == jira_body

        fields["description"] = local_body.empty? ? nil : adf(local_body)
      end

      def maybe_update_labels(fields, issue_file, jira_fields)
        return unless allow?("labels")
        return if issue_file.labels.sort == Array(jira_fields["labels"]).sort

        fields["labels"] = issue_file.labels
      end

      def maybe_update_components(fields, issue_file, jira_fields)
        return unless allow?("components")

        jira_comps = Array(jira_fields["components"]).map { |c| c["name"] }.sort
        return if issue_file.components.sort == jira_comps

        fields["components"] = components_payload(issue_file)
      end

      def maybe_update_priority(fields, issue_file, jira_fields)
        return unless allow?("priority") && issue_file.priority
        return if issue_file.priority == jira_fields.dig("priority", "name")

        fields["priority"] = { "name" => issue_file.priority }
      end

      def allow?(field)
        @push_config.fetch("allow_#{field}", false)
      end

      def adf(markdown)
        @converter.convert(markdown)
      end

      def components_payload(issue_file)
        issue_file.components.map { |c| { "name" => c } }
      end
    end
  end
end
