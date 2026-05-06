require "spec_helper"
require "taskmate/security/action_gate"

RSpec.describe Taskmate::Security::ActionGate do
  let(:output) { StringIO.new }

  def change(field:, from:, to:)
    described_class::FieldChange.new(field: field, from: from, to: to)
  end

  let(:plan) do
    described_class::ActionPlan.build(
      field_changes: [change(field: "status", from: "Open", to: "In Progress")],
      warnings:      ["read-only field 'key' was not changed"]
    )
  end

  describe "#confirm in non_interactive mode" do
    subject(:gate) { described_class.new(output: output, non_interactive: true) }

    it "returns :deny without prompting" do
      expect(gate.confirm(plan)).to eq(:deny)
    end

    it "does not print anything" do
      gate.confirm(plan)
      expect(output.string).to be_empty
    end
  end

  describe "#confirm in interactive mode" do
    def gate_with_input(answer)
      input = StringIO.new(answer)
      described_class.new(input: input, output: output, non_interactive: false)
    end

    it "returns :allow when user enters 'y'" do
      expect(gate_with_input("y\n").confirm(plan)).to eq(:allow)
    end

    it "returns :deny when user enters 'n'" do
      expect(gate_with_input("n\n").confirm(plan)).to eq(:deny)
    end

    it "returns :deny when user just hits Enter" do
      expect(gate_with_input("\n").confirm(plan)).to eq(:deny)
    end

    it "shows field changes in output" do
      gate_with_input("n\n").confirm(plan)
      expect(output.string).to include("status")
      expect(output.string).to include("Open")
      expect(output.string).to include("In Progress")
    end

    it "shows warnings in output" do
      gate_with_input("n\n").confirm(plan)
      expect(output.string).to include("read-only field")
    end

    it "shows '(no field changes)' when plan has no changes" do
      empty_plan = described_class::ActionPlan.build
      gate_with_input("n\n").confirm(empty_plan)
      expect(output.string).to include("no field changes")
    end
  end

  describe "ActionPlan.build" do
    it "defaults to empty field_changes array" do
      plan = described_class::ActionPlan.build
      expect(plan.field_changes).to eq([])
    end

    it "defaults to empty warnings array" do
      plan = described_class::ActionPlan.build
      expect(plan.warnings).to eq([])
    end
  end
end
