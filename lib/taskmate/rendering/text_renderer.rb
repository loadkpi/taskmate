require "taskmate/cli/output"
require "taskmate/rendering/diff_renderer"

module Taskmate
  module Rendering
    # Mixin module providing text-format rendering for CLI commands.
    # Include in a command class and call the render_* methods directly.
    module TextRenderer
      def render_show_text(issue, metadata: false)
        puts "#{issue.key || '(new)'}  #{issue.summary}"
        puts "Status: #{issue.status}  Priority: #{issue.priority}  Type: #{issue.issue_type}"
        puts "Assignee: #{issue.assignee&.display_name || '(unassigned)'}"
        puts "Labels: #{issue.labels.join(', ')}" if issue.labels.any?
        puts ""
        puts issue.body

        return unless metadata

        puts "\n--- Metadata ---"
        issue.frontmatter.each { |k, v| puts "#{k}: #{v}" }
      end

      def render_diff_text(diff)
        if diff.empty?
          puts "No changes in #{diff.issue_key}"
        else
          puts "Diff for #{diff.issue_key} (vs last pull):\n\n"
          puts DiffRenderer.render(diff.to_s)
        end
      end

      def render_validate_text(result)
        if result.valid?
          puts "#{result.issue_file.key}: valid"
        else
          puts "#{result.issue_file.key}: #{result.errors.size} error(s)"
          result.errors.each do |e|
            puts "  Line #{e.line_number}: #{e.feature} — #{e.message}"
          end
        end
      end

      def render_workspace_status_text(result)
        if workspace_all_empty?(result)
          puts "Workspace is empty — no issues found."
          return
        end

        print_workspace_section("Local changes (#{result.local_changed.size})", result.local_changed, "M")
        print_workspace_section("New local (#{result.new_local.size})", result.new_local, "+")
        print_workspace_section("Clean (#{result.clean.size})", result.clean, " ")

        return unless result.conflict_files.any?

        puts "\nUnresolved conflict files (#{result.conflict_files.size}):"
        result.conflict_files.each { |f| puts "  ! #{File.basename(f)}" }
      end

      def render_pull_single_text(result)
        CLI::Output.success("Pulled #{result.issue_file.key} → #{result.path}")
        return unless result.unsupported_nodes.any?

        CLI::Output.warn("  Warning: unsupported ADF nodes: #{result.unsupported_nodes.join(', ')}")
        CLI::Output.warn("  ADF backup saved to #{result.adf_backup_path}")
      end

      def render_pull_batch_text(batch)
        puts "Pulled #{batch.pulled.size}/#{batch.total} issues."
        batch.failed.each { |f| warn "  FAILED #{f.key}: #{f.error}" }
      end

      def render_push_text(result)
        if result.dry_run
          CLI::Output.info("[DRY RUN] Would push #{result.issue_file.key}")
          result.action_plan.field_changes.each do |c|
            CLI::Output.info("  #{c.field}: #{c.from} → #{c.to}")
          end
          result.action_plan.warnings.each { |w| CLI::Output.warn("  ! #{w}") }
        elsif result.applied
          CLI::Output.success("Pushed #{result.issue_file.key} to Jira.")
          CLI::Output.info("  Audit: #{result.audit_path}") if result.audit_path
        else
          CLI::Output.info("Push cancelled.")
        end
      end

      private

      def workspace_all_empty?(result)
        result.clean.empty? && result.local_changed.empty? &&
          result.new_local.empty? && result.conflict_files.empty?
      end

      def print_workspace_section(header, issues, prefix)
        return if issues.empty?

        puts "\n#{header}:"
        issues.each do |issue|
          key  = issue.key || "(new)"
          summ = issue.summary.to_s[0, 60]
          puts "  #{prefix} #{key.ljust(12)} #{summ}"
        end
      end
    end
  end
end
