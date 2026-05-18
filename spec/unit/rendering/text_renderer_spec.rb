require "spec_helper"
require "taskmate/rendering/text_renderer"

RSpec.describe Taskmate::Rendering::TextRenderer do
  subject(:renderer) do
    Class.new { include Taskmate::Rendering::TextRenderer }.new
  end

  # -- helpers --

  def make_issue(**opts)
    defaults = { key: "FOO-1", summary: "Summary", status: "Open",
                 priority: "High", issue_type: "Story", assignee: nil,
                 labels: [], body: "Body text", frontmatter: {} }
    double("issue_file", **defaults.merge(opts))
  end

  def make_assignee(display_name: "Alice")
    double("assignee", display_name: display_name)
  end

  # -- render_show_text --

  describe "#render_show_text" do
    it "prints key, summary, status, priority, type, assignee and body" do
      issue = make_issue
      expect { renderer.render_show_text(issue) }.to output(
        /FOO-1.*Summary.*Status: Open.*Priority: High.*Type: Story.*\(unassigned\).*Body text/m
      ).to_stdout
    end

    it "prints labels when present" do
      issue = make_issue(labels: %w[bug backend])
      expect { renderer.render_show_text(issue) }.to output(/Labels: bug, backend/).to_stdout
    end

    it "skips labels line when empty" do
      issue = make_issue(labels: [])
      expect { renderer.render_show_text(issue) }.not_to output(/Labels:/).to_stdout
    end

    it "prints assignee display name" do
      issue = make_issue(assignee: make_assignee(display_name: "Bob"))
      expect { renderer.render_show_text(issue) }.to output(/Assignee: Bob/).to_stdout
    end

    it "prints metadata block when metadata: true" do
      issue = make_issue(frontmatter: { "jira_id" => "10001" })
      expect { renderer.render_show_text(issue, metadata: true) }.to output(
        /--- Metadata ---.*jira_id: 10001/m
      ).to_stdout
    end

    it "omits metadata block when metadata: false" do
      issue = make_issue(frontmatter: { "jira_id" => "10001" })
      expect { renderer.render_show_text(issue, metadata: false) }.not_to output(/Metadata/).to_stdout
    end
  end

  # -- render_diff_text --

  describe "#render_diff_text" do
    let(:empty_diff) { double("diff", issue_key: "FOO-2", empty?: true, to_s: "") }
    let(:non_empty_diff) do
      double("diff", issue_key: "FOO-2", empty?: false,
                     to_s: "+new line\n-old line\n")
    end

    it "prints 'No changes' when diff is empty" do
      expect { renderer.render_diff_text(empty_diff) }.to output(/No changes in FOO-2/).to_stdout
    end

    it "prints diff header when diff has content" do
      expect { renderer.render_diff_text(non_empty_diff) }.to output(
        /Diff for FOO-2 \(vs last pull\)/
      ).to_stdout
    end

    it "includes diff content in output" do
      expect { renderer.render_diff_text(non_empty_diff) }.to output(/new line/).to_stdout
    end
  end

  # -- render_validate_text --

  describe "#render_validate_text" do
    let(:issue) { make_issue }

    it "prints 'valid' when result is valid" do
      result = double("result", issue_file: issue, valid?: true, errors: [])
      expect { renderer.render_validate_text(result) }.to output(/FOO-1: valid/).to_stdout
    end

    it "prints error count when invalid" do
      error = double("error", line_number: 3, feature: "status", message: "bad value")
      result = double("result", issue_file: issue, valid?: false, errors: [error])
      expect { renderer.render_validate_text(result) }.to output(/FOO-1: 1 error\(s\)/).to_stdout
    end

    it "prints each error with line, feature and message" do
      error = double("error", line_number: 5, feature: "priority", message: "unknown")
      result = double("result", issue_file: issue, valid?: false, errors: [error])
      expect { renderer.render_validate_text(result) }.to output(
        /Line 5: priority — unknown/
      ).to_stdout
    end
  end

  # -- render_workspace_status_text --

  describe "#render_workspace_status_text" do
    def make_ws_result(local_changed: [], new_local: [], clean: [], conflict_files: [])
      double("ws_result",
             local_changed: local_changed,
             new_local: new_local,
             clean: clean,
             conflict_files: conflict_files)
    end

    it "prints empty message when workspace has no issues" do
      result = make_ws_result
      expect { renderer.render_workspace_status_text(result) }.to output(
        /Workspace is empty/
      ).to_stdout
    end

    it "prints local changed section" do
      issue  = make_issue(key: "FOO-1", summary: "Changed issue")
      result = make_ws_result(local_changed: [issue])
      expect { renderer.render_workspace_status_text(result) }.to output(
        /Local changes.*M.*FOO-1/m
      ).to_stdout
    end

    it "prints new local section" do
      issue  = make_issue(key: nil, summary: "Brand new")
      result = make_ws_result(new_local: [issue])
      expect { renderer.render_workspace_status_text(result) }.to output(
        /New local.*\+.*\(new\)/m
      ).to_stdout
    end

    it "prints clean section" do
      issue  = make_issue(key: "FOO-3", summary: "Unchanged")
      result = make_ws_result(clean: [issue])
      expect { renderer.render_workspace_status_text(result) }.to output(/FOO-3/).to_stdout
    end

    it "prints conflict files section" do
      result = make_ws_result(
        clean: [make_issue],
        conflict_files: ["/workspace/issues/FOO-1.md.conflict"]
      )
      expect { renderer.render_workspace_status_text(result) }.to output(
        /Unresolved conflict files.*FOO-1\.md\.conflict/m
      ).to_stdout
    end

    it "truncates long summaries to 60 characters" do
      long_summary = "A" * 80
      issue  = make_issue(summary: long_summary)
      result = make_ws_result(clean: [issue])
      output = capture_stdout { renderer.render_workspace_status_text(result) }
      expect(output).to include("A" * 60)
      expect(output).not_to include("A" * 61)
    end
  end

  # -- render_pull_single_text --

  describe "#render_pull_single_text" do
    it "outputs success message" do
      result = double("result",
                      issue_file: make_issue,
                      path: "/issues/FOO-1.md",
                      unsupported_nodes: [])
      expect { renderer.render_pull_single_text(result) }.to output(/Pulled FOO-1/).to_stdout
    end

    it "warns about unsupported ADF nodes" do
      result = double("result",
                      issue_file: make_issue,
                      path: "/issues/FOO-1.md",
                      unsupported_nodes: %w[expand],
                      adf_backup_path: "/issues/FOO-1.adf.json")
      expect { renderer.render_pull_single_text(result) }.to output(/unsupported ADF nodes: expand/).to_stderr
    end
  end

  # -- render_pull_batch_text --

  describe "#render_pull_batch_text" do
    it "prints pulled count" do
      r1 = double("r", issue_file: make_issue(key: "FOO-1"), path: "/p1")
      r2 = double("r", issue_file: make_issue(key: "FOO-2"), path: "/p2")
      batch = double("batch", total: 2, pulled: [r1, r2], failed: [])
      expect { renderer.render_pull_batch_text(batch) }.to output(%r{Pulled 2/2 issues}).to_stdout
    end

    it "prints failures to stderr" do
      f = double("failure", key: "FOO-9", error: "not found")
      batch = double("batch", total: 1, pulled: [], failed: [f])
      expect { renderer.render_pull_batch_text(batch) }.to output(/FAILED FOO-9: not found/).to_stderr
    end
  end

  # -- render_push_text --

  describe "#render_push_text" do
    let(:issue) { make_issue }

    it "prints dry run header" do
      change = double("change", field: "summary", from: "Old", to: "New")
      plan   = double("plan", field_changes: [change], warnings: [])
      result = double("result", issue_file: issue, dry_run: true, applied: false,
                                action_plan: plan, audit_path: nil)
      expect { renderer.render_push_text(result) }.to output(/DRY RUN.*Would push FOO-1/m).to_stdout
    end

    it "prints field changes in dry run" do
      change = double("change", field: "summary", from: "Old", to: "New")
      plan   = double("plan", field_changes: [change], warnings: [])
      result = double("result", issue_file: issue, dry_run: true, applied: false,
                                action_plan: plan, audit_path: nil)
      expect { renderer.render_push_text(result) }.to output(/summary: Old → New/).to_stdout
    end

    it "prints success when applied" do
      result = double("result", issue_file: issue, dry_run: false, applied: true,
                                audit_path: nil)
      expect { renderer.render_push_text(result) }.to output(/Pushed FOO-1 to Jira/).to_stdout
    end

    it "prints audit path when present" do
      result = double("result", issue_file: issue, dry_run: false, applied: true,
                                audit_path: "/audit/FOO-1.json")
      expect { renderer.render_push_text(result) }.to output(/Audit:.*FOO-1\.json/).to_stdout
    end

    it "prints cancelled message" do
      result = double("result", issue_file: issue, dry_run: false, applied: false,
                                audit_path: nil)
      expect { renderer.render_push_text(result) }.to output(/Push cancelled/).to_stdout
    end
  end

  # -- helpers (private) --

  def capture_stdout
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end
end
