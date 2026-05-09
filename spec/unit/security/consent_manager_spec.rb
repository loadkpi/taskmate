require "spec_helper"
require "taskmate/security/consent_manager"

RSpec.describe Taskmate::Security::ConsentManager do
  let(:output) { StringIO.new }
  let(:context) do
    described_class::ConsentContext.new(
      provider: "openai",
      model: "gpt-4o",
      files: ["issues/SAR-1.md"],
      sections: ["body (safe)"],
      excluded_paths: []
    )
  end

  describe "#request in non_interactive mode" do
    subject(:manager) { described_class.new(output: output, non_interactive: true) }

    it "returns :deny without prompting" do
      expect(manager.request(context)).to eq(:deny)
    end

    it "does not print anything" do
      manager.request(context)
      expect(output.string).to be_empty
    end
  end

  describe "#request in interactive mode" do
    def manager_with_input(answer)
      input = StringIO.new(answer)
      described_class.new(input: input, output: output, non_interactive: false)
    end

    it "returns :allow when user enters 'y'" do
      expect(manager_with_input("y\n").request(context)).to eq(:allow)
    end

    it "returns :allow when user enters 'Y'" do
      expect(manager_with_input("Y\n").request(context)).to eq(:allow)
    end

    it "returns :deny when user enters 'n'" do
      expect(manager_with_input("n\n").request(context)).to eq(:deny)
    end

    it "returns :deny when user just hits Enter (empty, default N)" do
      expect(manager_with_input("\n").request(context)).to eq(:deny)
    end

    it "returns :deny when user enters anything other than y" do
      expect(manager_with_input("yes\n").request(context)).to eq(:deny)
    end

    it "shows provider in disclosure" do
      manager_with_input("n\n").request(context)
      expect(output.string).to include("openai")
    end

    it "shows file list in disclosure" do
      manager_with_input("n\n").request(context)
      expect(output.string).to include("SAR-1.md")
    end
  end

  describe Taskmate::Security::FakeConsentManager do
    it "returns :allow by default" do
      expect(described_class.new.request(nil)).to eq(:allow)
    end

    it "returns :deny when configured" do
      expect(described_class.new(response: :deny).request(nil)).to eq(:deny)
    end
  end
end
