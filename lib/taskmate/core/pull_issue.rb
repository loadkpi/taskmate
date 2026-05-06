require "fileutils"
require "taskmate/jira/issue_mapper"
require "taskmate/jira/adf_backup"
require "taskmate/workspace/issue_file"
require "taskmate/workspace/canonical_hash"

module Taskmate
  module Core
    class PullIssue
      PullResult = Struct.new(:issue_file, :path, :synced_path, :adf_backup_path,
                              :unsupported_nodes, keyword_init: true)

      def initialize(workspace_path:, jira_client:, story_points_field: nil)
        @workspace_path     = workspace_path
        @jira_client        = jira_client
        @mapper             = Jira::IssueMapper.new(story_points_field: story_points_field)
      end

      def call(key)
        jira_issue = @jira_client.find_issue(key)
        issue, conversion = @mapper.map(jira_issue)

        issue_path  = issue_file_path(key)
        synced_path = synced_copy_path(key)

        FileUtils.mkdir_p(File.dirname(issue_path))
        FileUtils.mkdir_p(File.dirname(synced_path))

        # Set the hash that represents the clean state
        issue.last_synced_local_hash = issue.jira_source_hash

        issue.write(issue_path)

        # Write synced reference copy for offline diff
        write_synced_copy(issue, synced_path)

        # ADF backup when unsupported nodes present
        adf_backup_path = save_adf_backup(key, jira_issue["fields"]&.dig("description"),
                                          conversion.unsupported_nodes)

        PullResult.new(
          issue_file:       issue,
          path:             issue_path,
          synced_path:      synced_path,
          adf_backup_path:  adf_backup_path,
          unsupported_nodes: conversion.unsupported_nodes
        )
      end

      private

      def issue_file_path(key)
        File.join(@workspace_path, "issues", "#{key}.md")
      end

      def synced_copy_path(key)
        File.join(@workspace_path, "issues", ".jira", "#{key}.synced.md")
      end

      def write_synced_copy(issue, path)
        require "taskmate/workspace/frontmatter_file"
        content = Workspace::FrontmatterFile.serialize(issue.frontmatter, issue.body)
        tmp = "#{path}.tmp.#{Process.pid}"
        File.write(tmp, content, encoding: "utf-8")
        File.rename(tmp, path)
      end

      def save_adf_backup(key, adf, unsupported_nodes)
        Jira::AdfBackup.save(
          key:              key,
          adf:              adf,
          workspace_path:   @workspace_path,
          unsupported_nodes: unsupported_nodes
        )
      end
    end
  end
end
