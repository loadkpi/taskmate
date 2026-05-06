require "spec_helper"
require "taskmate/workspace/initializer"
require "taskmate/cli/commands/init"

RSpec.describe Taskmate::Workspace::Initializer do
  subject(:initializer) do
    described_class.new(workspace_path: workspace, interactive: false, prompt: nil)
  end

  let(:workspace) { create_temp_workspace }

  describe "#call" do
    let(:result) { initializer.call }

    it "creates all required directories" do
      result
      Taskmate::Workspace::DIRECTORIES.each do |dir|
        expect(Dir.exist?(File.join(workspace, dir))).to be(true), "expected #{dir} to exist"
      end
    end

    it "creates workspace.yml" do
      result
      expect(File.exist?(File.join(workspace, "workspace.yml"))).to be(true)
    end

    it "creates .taskmateignore" do
      result
      expect(File.exist?(File.join(workspace, ".taskmateignore"))).to be(true)
    end

    it ".taskmateignore contains basic secret patterns" do
      result
      content = File.read(File.join(workspace, ".taskmateignore"))
      expect(content).to include("*.key")
      expect(content).to include(".env")
      expect(content).to include("secrets.yml")
    end

    it "generates valid YAML in workspace.yml" do
      result
      content = YAML.safe_load_file(File.join(workspace, "workspace.yml"))
      expect(content).to be_a(Hash)
    end

    it "sets security defaults to safe values" do
      result
      config = YAML.safe_load_file(File.join(workspace, "workspace.yml"))
      security = config["security"]
      expect(security["require_consent_for_ai"]).to be(true)
      expect(security["require_confirm_for_push"]).to be(true)
      expect(security["secret_detection"]).to be(true)
    end

    it "sets AI provider to disabled by default" do
      result
      config = YAML.safe_load_file(File.join(workspace, "workspace.yml"))
      expect(config.dig("ai", "provider")).to eq("disabled")
    end

    it "workspace.yml has all required sections" do
      result
      config = YAML.safe_load_file(File.join(workspace, "workspace.yml"))
      expect(config.keys).to include("version", "tracker", "ai", "security", "push")
    end

    it "returns list of created directories" do
      expect(result[:created_dirs]).to include("issues", "reviews", "audit")
    end

    it "reports skills_copied status" do
      expect(result[:skills_copied]).to be_a(Symbol)
      expect(%i[copied already_present unavailable]).to include(result[:skills_copied])
    end

    context "when workspace.yml already exists" do
      before do
        File.write(File.join(workspace, "workspace.yml"), YAML.dump("version" => 1, "existing" => true))
      end

      it "does not overwrite workspace.yml" do
        result
        config = YAML.safe_load_file(File.join(workspace, "workspace.yml"))
        expect(config["existing"]).to be(true)
      end

      it "reports workspace_yml_exists in result" do
        expect(result[:workspace_yml_exists]).to be(true)
      end
    end

    context "when directories already exist" do
      before do
        FileUtils.mkdir_p(File.join(workspace, "issues"))
        FileUtils.mkdir_p(File.join(workspace, "reviews"))
      end

      it "reports existing dirs without failing" do
        expect(result[:existing_dirs]).to include("issues", "reviews")
      end

      it "still creates missing directories" do
        result
        expect(Dir.exist?(File.join(workspace, "audit/actions"))).to be(true)
      end
    end

    context "on second run (--non-interactive)" do
      it "reports existing directories and workspace.yml_exists" do
        initializer.call
        second_result = initializer.call
        expect(second_result[:existing_dirs]).to include("issues")
        expect(second_result[:workspace_yml_exists]).to be(true)
      end
    end
  end
end

RSpec.describe Taskmate::CLI::Commands::Init do
  subject(:command) { described_class.new(non_interactive: true) }

  let(:workspace) { create_temp_workspace }

  describe "#call (non-interactive)" do
    it "prints success output" do
      expect { command.call(workspace) }.to output(/Workspace initialized/).to_stdout
    end

    it "creates workspace structure" do
      command.call(workspace)
      expect(File.exist?(File.join(workspace, "workspace.yml"))).to be(true)
    end
  end
end
