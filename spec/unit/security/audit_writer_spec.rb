require "spec_helper"
require "taskmate/security/audit_writer"
require "yaml"

RSpec.describe Taskmate::Security::AuditWriter do
  let(:tmpdir)  { Dir.mktmpdir }
  let(:writer)  { described_class.new(workspace_path: tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  describe "#write_action_audit" do
    let(:path) do
      writer.write_action_audit(
        fields_changed: %w[status priority],
        user_confirmed: true,
        dry_run: false,
        issue_key: "SAR-1",
        warnings: ["read-only field skipped"]
      )
    end

    it "creates a file under audit/actions/" do
      expect(path).to include("audit/actions")
      expect(File.exist?(path)).to be(true)
    end

    it "filename contains a millisecond timestamp and random hex suffix" do
      name = File.basename(path)
      expect(name).to match(/\A\d{13}-actions-[0-9a-f]{8}\.yml\z/)
    end

    it "writes valid YAML" do
      data = YAML.safe_load_file(path)
      expect(data).to be_a(Hash)
    end

    it "includes expected fields in YAML" do
      data = YAML.safe_load_file(path)
      expect(data["type"]).to eq("action_audit")
      expect(data["fields_changed"]).to eq(%w[status priority])
      expect(data["user_confirmed"]).to be(true)
      expect(data["dry_run"]).to be(false)
      expect(data["issue_key"]).to eq("SAR-1")
      expect(data["warnings"]).to eq(["read-only field skipped"])
    end

    it "never contains API keys or raw tokens" do
      content = File.read(path)
      expect(content).not_to match(/AKIA/)
      expect(content).not_to match(/ghp_/)
      expect(content).not_to match(/Bearer /)
    end
  end

  describe "#write_ai_audit" do
    let(:path) do
      writer.write_ai_audit(
        skill: "suggest_fix",
        provider: "openai",
        model: "gpt-4o",
        prompt_hash: "sha256:abc123",
        issue_key: "SAR-2"
      )
    end

    it "creates a file under audit/ai/" do
      expect(path).to include("audit/ai")
      expect(File.exist?(path)).to be(true)
    end

    it "filename matches expected pattern" do
      name = File.basename(path)
      expect(name).to match(/\A\d{13}-ai-[0-9a-f]{8}\.yml\z/)
    end

    it "includes expected fields in YAML" do
      data = YAML.safe_load_file(path)
      expect(data["type"]).to eq("ai_call_audit")
      expect(data["skill"]).to eq("suggest_fix")
      expect(data["provider"]).to eq("openai")
      expect(data["model"]).to eq("gpt-4o")
      expect(data["prompt_hash"]).to eq("sha256:abc123")
      expect(data["issue_key"]).to eq("SAR-2")
    end

    it "does not store raw prompt text" do
      data = YAML.safe_load_file(path)
      expect(data.keys).not_to include("prompt")
    end
  end

  describe ".prompt_hash" do
    it "returns a sha256: prefixed string" do
      hash = described_class.prompt_hash("some prompt text")
      expect(hash).to start_with("sha256:")
    end

    it "is deterministic for the same input" do
      hash1 = described_class.prompt_hash("x")
      hash2 = described_class.prompt_hash("x")
      expect(hash1).to eq(hash2)
    end

    it "differs for different inputs" do
      expect(described_class.prompt_hash("a")).not_to eq(described_class.prompt_hash("b"))
    end
  end
end
