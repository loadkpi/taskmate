require "spec_helper"
require "taskmate/doctor/runner"
require "taskmate/cli/commands/doctor"

RSpec.describe Taskmate::Doctor::Runner do
  subject(:runner) { described_class.new(workspace_path: workspace) }

  describe "#run in initialized workspace" do
    let(:workspace) { create_temp_workspace(initialized: true) }

    it "runs all checks and returns them" do
      checks = runner.run
      expect(checks).to all(be_a(Taskmate::Doctor::Check))
    end

    it "has no FAILed checks in a valid workspace" do
      checks = runner.run
      failed = checks.select { |c| c.status == :fail }
      expect(failed).to be_empty,
        "Expected no failures but got: #{failed.map { |c| "#{c.name}: #{c.message}" }.join(", ")}"
    end

    it "workspace.yml check passes (ok)" do
      checks = runner.run
      check = checks.find { |c| c.name == "workspace.yml" }
      expect(check.status).to eq(:ok)
    end

    it "directories check passes (ok)" do
      checks = runner.run
      check = checks.find { |c| c.name == "workspace directories" }
      expect(check.status).to eq(:ok)
    end

    it ".taskmateignore check passes (ok)" do
      checks = runner.run
      check = checks.find { |c| c.name == ".taskmateignore" }
      expect(check.status).to eq(:ok)
    end

    it "security config check passes (ok)" do
      checks = runner.run
      check = checks.find { |c| c.name == "security config" }
      expect(check.status).to eq(:ok)
    end

    it "no-secrets check passes (ok) on clean workspace" do
      checks = runner.run
      check = checks.find { |c| c.name == "no secrets in workspace root" }
      expect(check.status).to eq(:ok)
    end

    it "built-in skills check is ok or skip (not fail) after init" do
      checks = runner.run
      check = checks.find { |c| c.name == "built-in skills" }
      expect(%i[ok skip]).to include(check.status)
    end

    it "Jira check is SKIP" do
      checks = runner.run
      check = checks.find { |c| c.name == "Jira connectivity" }
      expect(check.status).to eq(:skip)
    end

    it "AI check is SKIP" do
      checks = runner.run
      check = checks.find { |c| c.name == "AI provider" }
      expect(check.status).to eq(:skip)
    end
  end

  describe "#run without workspace.yml" do
    let(:workspace) { create_temp_workspace }

    it "workspace.yml check fails" do
      checks = runner.run
      check = checks.find { |c| c.name == "workspace.yml" }
      expect(check.status).to eq(:fail)
    end

    it "directories check fails" do
      checks = runner.run
      check = checks.find { |c| c.name == "workspace directories" }
      expect(check.status).to eq(:fail)
    end
  end

  describe "#run with malformed workspace.yml" do
    let(:workspace) do
      dir = create_temp_workspace
      File.write(File.join(dir, "workspace.yml"), "!!invalid: [yaml")
      dir
    end

    it "workspace.yml check fails with clear message" do
      checks = runner.run
      check = checks.find { |c| c.name == "workspace.yml" }
      expect(check.status).to eq(:fail)
    end
  end

  describe "extensibility — registering custom checks" do
    let(:workspace) { create_temp_workspace(initialized: true) }
    let(:custom_check) do
      check = Taskmate::Doctor::Check.new(name: "custom", description: "Custom check")
      allow(check).to receive(:run) { check.send(:ok!, "custom passed") }
      check
    end

    it "includes custom check in results" do
      runner.register(custom_check)
      checks = runner.run
      custom = checks.find { |c| c.name == "custom" }
      expect(custom).not_to be_nil
      expect(custom.status).to eq(:ok)
    end
  end
end

RSpec.describe Taskmate::CLI::Commands::Doctor do
  subject(:command) { described_class.new }

  describe "#call" do
    context "with valid initialized workspace" do
      let(:workspace) { create_temp_workspace(initialized: true) }

      it "outputs doctor results" do
        expect { command.call(workspace) }.to output(/Taskmate doctor/).to_stdout
      end

      it "does not call exit 1 when all checks pass" do
        expect(command).not_to receive(:exit)
        command.call(workspace)
      end
    end

    context "without workspace.yml" do
      let(:workspace) { create_temp_workspace }

      it "calls exit 1 when there are failures" do
        expect { command.call(workspace) }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end
  end
end
