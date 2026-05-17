require "spec_helper"
require "json"
require "taskmate/cli/commands/skills"

RSpec.describe Taskmate::CLI::Commands::Skills do
  let(:workspace) { create_temp_workspace(initialized: true) }

  # A minimal valid skill fixture
  def write_skill(id:, kind: "task_review", valid: true)
    content = if valid
                <<~MD
                  ---
                  id: #{id}
                  version: 1
                  kind: #{kind}
                  description: "Test skill #{id}"
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

                  Skill prompt body for #{id}.
                MD
              else
                # Missing required fields: id, security
                <<~MD
                  ---
                  version: 1
                  kind: #{kind}
                  description: "Broken skill"
                  ---

                  Prompt body.
                MD
              end

    write_file(workspace, "skills/#{id}/skill.md", content)
  end

  describe "#list" do
    context "with text output" do
      subject(:command) { described_class.new(format: "text") }

      it "lists installed skills with id, version and kind" do
        write_skill(id: "my-skill")

        output = capture_stdout { command.list(workspace) }

        expect(output).to include("my-skill")
        expect(output).to include("1")
        expect(output).to include("task_review")
      end

      it "prints message when no skills directory exists" do
        empty_workspace = create_temp_workspace
        output = capture_stdout { command.list(empty_workspace) }

        expect(output).to include("No skills found")
      end
    end

    context "with json output" do
      subject(:command) { described_class.new(format: "json") }

      it "returns skills as json array with id, version, kind" do
        write_skill(id: "my-skill")

        data = JSON.parse(capture_stdout { command.list(workspace) })

        skill = data.find { |s| s["id"] == "my-skill" }
        expect(skill).not_to be_nil
        expect(skill["version"]).to eq("1")
        expect(skill["kind"]).to eq("task_review")
      end
    end

    context "with invalid format" do
      subject(:command) { described_class.new(format: "yaml") }

      it "raises ValidationError" do
        expect { command.list(workspace) }
          .to raise_error(Taskmate::ValidationError, /Invalid format/)
      end
    end
  end

  describe "#show" do
    context "with text output" do
      subject(:command) { described_class.new(format: "text") }

      it "prints skill details in text format" do
        write_skill(id: "my-skill")

        output = capture_stdout { command.show("my-skill", workspace) }

        expect(output).to include("id:          my-skill")
        expect(output).to include("version:     1")
        expect(output).to include("kind:        task_review")
        expect(output).to include("description: Test skill my-skill")
        expect(output).to include("requires_ai: true")
      end
    end

    context "with json output" do
      subject(:command) { described_class.new(format: "json") }

      it "returns skill details as json" do
        write_skill(id: "my-skill")

        data = JSON.parse(capture_stdout { command.show("my-skill", workspace) })

        expect(data["id"]).to eq("my-skill")
        expect(data["version"]).to eq("1")
        expect(data["kind"]).to eq("task_review")
        expect(data["description"]).to eq("Test skill my-skill")
        expect(data["requires_ai"]).to eq(true)
        expect(data["inputs"]).to be_an(Array)
        expect(data["outputs"]).to be_an(Array)
      end
    end

    context "when skill does not exist" do
      subject(:command) { described_class.new(format: "text") }

      it "raises SkillLoadError" do
        expect { command.show("missing-skill", workspace) }
          .to raise_error(Taskmate::Skills::Loader::SkillLoadError, /missing-skill/)
      end
    end
  end

  describe "#validate" do
    context "with text output" do
      subject(:command) { described_class.new(format: "text") }

      it "prints OK for valid skills and reports all skills valid" do
        write_skill(id: "my-skill")

        output = capture_stdout { command.validate(workspace) }

        expect(output).to include("[OK] my-skill")
        expect(output).to include("All skills valid.")
      end

      it "prints FAIL and exits with status 1 for invalid skills" do
        write_skill(id: "broken-skill", valid: false)

        output, exit_error = capture_stdout_and_system_exit { command.validate(workspace) }

        expect(output).to include("[FAIL] broken-skill")
        expect(output).to include("Some skills have errors.")
        expect(exit_error).to be_a(SystemExit)
        expect(exit_error.status).to eq(1)
      end
    end

    context "with json output" do
      subject(:command) { described_class.new(format: "json") }

      it "returns validation results as json array" do
        write_skill(id: "my-skill")

        data = JSON.parse(capture_stdout { command.validate(workspace) })

        entry = data.find { |r| r["id"] == "my-skill" }
        expect(entry).not_to be_nil
        expect(entry["valid"]).to eq(true)
        expect(entry["errors"]).to eq([])
      end
    end
  end
end
