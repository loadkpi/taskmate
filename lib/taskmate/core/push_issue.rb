require "fileutils"
require "taskmate/workspace/issue_file"
require "taskmate/workspace/frontmatter_file"
require "taskmate/jira/payload_builder"
require "taskmate/jira/conflict_detector"
require "taskmate/jira/issue_mapper"
require "taskmate/workspace/diff"
require "taskmate/security/action_gate"

module Taskmate
  module Core
    class PushIssue
      PushResult = Struct.new(
        :issue_file, :applied, :dry_run, :action_plan, :audit_path,
        keyword_init: true
      )

      READ_ONLY_FIELDS = %w[status assignee reporter created updated].freeze

      def initialize(workspace_path:, jira_client:, security_policy:,
                     push_config: {}, story_points_field: nil)
        @workspace_path     = workspace_path
        @jira_client        = jira_client
        @security_policy    = security_policy
        @payload_builder    = Jira::PayloadBuilder.new(
          push_config:        push_config,
          story_points_field: story_points_field
        )
        @conflict_detector  = Jira::ConflictDetector.new(story_points_field: story_points_field)
        @mapper             = Jira::IssueMapper.new(story_points_field: story_points_field)
        @story_points_field = story_points_field
      end

      def call(key_or_path, dry_run: false)
        issue_path = resolve_path(key_or_path)
        raise IssueNotFoundError, "File not found: #{issue_path}" unless File.exist?(issue_path)

        issue = Workspace::IssueFile.read(issue_path)

        if issue.new_local?
          push_new(issue, dry_run: dry_run)
        else
          push_existing(issue, dry_run: dry_run)
        end
      end

      private

      def resolve_path(key_or_path)
        return key_or_path if File.exist?(key_or_path)

        File.join(@workspace_path, "issues", "#{key_or_path}.md")
      end

      def push_existing(issue, dry_run:)
        key     = issue.key
        jira_raw = @jira_client.find_issue(key)

        # Conflict check
        conflict = @conflict_detector.detect(
          local_issue:    issue,
          jira_issue_raw: jira_raw
        )

        if conflict.status == :conflict
          raise ConflictError,
                "#{key} has conflicting changes on Jira " \
                "(fields: #{conflict.changed_fields.join(", ")}). " \
                "Run `taskmate conflict show #{key}` for details."
        end

        jira_fields = jira_raw["fields"] || {}
        payload = @payload_builder.build_update(issue, jira_fields: jira_fields)

        field_changes = payload["fields"].map do |field, val|
          Security::ActionGate::FieldChange.new(
            field: field,
            from:  jira_fields[field].inspect,
            to:    val.inspect
          )
        end

        warnings = detect_read_only_warnings(issue, jira_fields)

        action_plan = Security::ActionGate::ActionPlan.build(
          field_changes: field_changes,
          warnings:      warnings
        )

        return PushResult.new(
          issue_file:  issue,
          applied:     false,
          dry_run:     true,
          action_plan: action_plan
        ) if dry_run

        decision = @security_policy.authorize_jira_write(action_plan)
        return PushResult.new(issue_file: issue, applied: false, dry_run: false, action_plan: action_plan) if decision == :deny

        @jira_client.update_issue(key, payload)

        # Re-fetch Jira's canonical version and write it to disk so that
        # the local body matches the stored hashes (avoids false conflicts).
        updated_raw = @jira_client.find_issue(key)
        updated_issue, = @mapper.map(updated_raw)
        updated_issue.last_synced_local_hash = updated_issue.jira_source_hash
        updated_issue.write(issue.path)
        write_synced_copy(updated_issue, synced_copy_path(key))

        audit_path = @security_policy.write_action_audit(
          fields_changed: payload["fields"].keys,
          user_confirmed: true,
          issue_key:      key,
          warnings:       warnings
        )

        PushResult.new(issue_file: updated_issue, applied: true, dry_run: false,
                       action_plan: action_plan, audit_path: audit_path)
      end

      def push_new(issue, dry_run:)
        payload = @payload_builder.build_create(issue)

        action_plan = Security::ActionGate::ActionPlan.build(
          field_changes: [
            Security::ActionGate::FieldChange.new(field: "action", from: nil, to: "create new Jira issue")
          ],
          warnings: []
        )

        return PushResult.new(
          issue_file:  issue,
          applied:     false,
          dry_run:     true,
          action_plan: action_plan
        ) if dry_run

        decision = @security_policy.authorize_jira_write(action_plan)
        return PushResult.new(issue_file: issue, applied: false, dry_run: false, action_plan: action_plan) if decision == :deny

        created = @jira_client.create_issue(payload)
        new_key = created["key"]

        # Fetch the newly created issue to get canonical Jira state
        fresh_raw    = @jira_client.find_issue(new_key)
        fresh_issue, = @mapper.map(fresh_raw)

        # Write Jira's canonical version to issues/<KEY>.md and synced copy
        old_path = issue.path
        new_path = File.join(@workspace_path, "issues", "#{new_key}.md")
        FileUtils.mkdir_p(File.dirname(new_path))
        fresh_issue.last_synced_local_hash = fresh_issue.jira_source_hash
        fresh_issue.write(new_path)
        write_synced_copy(fresh_issue, synced_copy_path(new_key))
        File.delete(old_path) if old_path && File.exist?(old_path) && old_path != new_path

        audit_path = @security_policy.write_action_audit(
          fields_changed: payload["fields"].keys + ["key"],
          user_confirmed: true,
          issue_key:      new_key
        )

        PushResult.new(issue_file: fresh_issue, applied: true, dry_run: false,
                       action_plan: action_plan, audit_path: audit_path)
      end

      def detect_read_only_warnings(issue, jira_fields)
        warnings = []
        READ_ONLY_FIELDS.each do |field|
          local  = issue.frontmatter[field]
          jira   = jira_fields[field]
          next if local.nil? || local == jira

          warnings << "Field '#{field}' changed locally but is read-only — will not be pushed"
        end
        warnings
      end

      def synced_copy_path(key)
        File.join(@workspace_path, "issues", ".jira", "#{key}.synced.md")
      end

      def write_synced_copy(issue, path)
        FileUtils.mkdir_p(File.dirname(path))
        content = Workspace::FrontmatterFile.serialize(issue.frontmatter, issue.body)
        tmp = "#{path}.tmp.#{Process.pid}"
        File.write(tmp, content, encoding: "utf-8")
        File.rename(tmp, path)
      end
    end
  end
end
