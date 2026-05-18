require "spec_helper"
require "taskmate/doctor/checks/skills_check"

RSpec.describe Taskmate::Doctor::Checks::SkillsCheck do
  subject(:check) { described_class.new(workspace_path: workspace) }

  def valid_skill_content(id)
    <<~MD
      ---
      id: #{id}
      version: 1
      kind: task_review
      description: "Built-in skill #{id}"
      requires_ai: true
      inputs:
        - name: issue_markdown
          type: markdown
          required: true
      outputs:
        - name: result_markdown
          type: markdown
      security:
        external_ai: requires_consent
        jira_write: false
      ---

      Prompt body for #{id}.
    MD
  end

  def write_valid_skills(*ids)
    ids.each do |id|
      write_file(workspace, "skills/#{id}/skill.md", valid_skill_content(id))
    end
  end

  context "when skills/ directory is missing" do
    let(:workspace) { create_temp_workspace }

    it "fails with a helpful message" do
      check.run
      expect(check.status).to eq(:fail)
      expect(check.message).to include("skills/ directory missing")
    end
  end

  context "when a built-in skill is missing from workspace" do
    let(:workspace) { create_temp_workspace }

    before do
      FileUtils.mkdir_p(File.join(workspace, "skills"))
      write_valid_skills("create-task", "improve-task")
      # review-task intentionally omitted
    end

    it "fails and names the missing skill" do
      check.run
      expect(check.status).to eq(:fail)
      expect(check.message).to include("review-task")
    end
  end

  context "when all skills are present and valid" do
    let(:workspace) { create_temp_workspace }

    before { write_valid_skills(*described_class::EXPECTED_SKILLS) }

    it "passes" do
      check.run
      expect(check.status).to eq(:ok)
      expect(check.message).to include("present and valid")
    end
  end

  context "when a skill file is present but invalid (missing required fields)" do
    let(:workspace) { create_temp_workspace }

    before do
      write_valid_skills("create-task", "review-task")
      # improve-task written without required inputs/outputs/security
      write_file(workspace, "skills/improve-task/skill.md", <<~MD)
        ---
        id: improve-task
        version: 1
        kind: task_review
        description: "Broken skill"
        ---

        Prompt.
      MD
    end

    it "fails and names the invalid skill" do
      check.run
      expect(check.status).to eq(:fail)
      expect(check.message).to include("improve-task")
    end
  end

  context "when a skill file has unparseable frontmatter (SkillLoadError)" do
    let(:workspace) { create_temp_workspace }

    before do
      write_valid_skills("create-task", "review-task")
      write_file(workspace, "skills/improve-task/skill.md", "---\nid: [invalid yaml\n---\n\nBody.\n")
    end

    it "fails and names the skill that could not be loaded" do
      check.run
      expect(check.status).to eq(:fail)
      expect(check.message).to include("improve-task")
    end
  end

  context "when builtins are not bundled (legacy gem version)" do
    let(:workspace) { create_temp_workspace }

    before do
      FileUtils.mkdir_p(File.join(workspace, "skills"))
      stub_const("#{described_class}::BUILTINS_DIR", "/nonexistent/path/builtins")
    end

    it "skips gracefully" do
      check.run
      expect(check.status).to eq(:skip)
    end
  end
end
