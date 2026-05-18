require "spec_helper"
require "taskmate/config"

RSpec.describe Taskmate::Config::Validator do
  # ─── errors ───────────────────────────────────────────────────────────────

  describe ".errors" do
    it "returns empty array for empty Hash" do
      expect(described_class.errors({})).to eq([])
    end

    it "returns error when root is not a Hash" do
      expect(described_class.errors("string")).to include("root must be a Hash")
      expect(described_class.errors(nil)).to include("root must be a Hash")
      expect(described_class.errors([])).to include("root must be a Hash")
    end

    context "tracker section" do
      it "returns no errors for valid tracker Hash" do
        expect(described_class.errors("tracker" => { "base_url" => "https://x.atlassian.net" })).to eq([])
      end

      it "returns error when tracker is not a Hash" do
        expect(described_class.errors("tracker" => "bad")).to include("tracker must be a Hash")
      end
    end

    context "ai section" do
      it "returns no errors for valid ai provider" do
        %w[openai anthropic ollama fake disabled].each do |p|
          expect(described_class.errors("ai" => { "provider" => p })).to eq([])
        end
      end

      it "returns error for unknown ai provider" do
        errs = described_class.errors("ai" => { "provider" => "unknown" })
        expect(errs).to include(match(/ai\.provider 'unknown' is invalid/))
      end

      it "returns error when ai is not a Hash" do
        expect(described_class.errors("ai" => 42)).to include("ai must be a Hash")
      end
    end

    context "security section" do
      it "returns no errors for valid boolean security flags" do
        raw = {
          "security" => {
            "require_consent_for_ai" => true,
            "require_confirm_for_push" => false,
            "secret_detection" => true
          }
        }
        expect(described_class.errors(raw)).to eq([])
      end

      it "returns error when a security flag is not boolean" do
        raw = { "security" => { "require_consent_for_ai" => "yes" } }
        errs = described_class.errors(raw)
        expect(errs).to include(match(/security\.require_consent_for_ai must be true or false/))
      end

      it "returns error when security is not a Hash" do
        expect(described_class.errors("security" => "enabled")).to include("security must be a Hash")
      end
    end

    context "push section" do
      it "returns no errors for valid push config" do
        raw = { "push" => { "allowed_fields" => %w[summary description] } }
        expect(described_class.errors(raw)).to eq([])
      end

      it "returns error when allowed_fields is not an Array" do
        raw = { "push" => { "allowed_fields" => "summary" } }
        expect(described_class.errors(raw)).to include("push.allowed_fields must be an Array")
      end

      it "returns error when push is not a Hash" do
        expect(described_class.errors("push" => true)).to include("push must be a Hash")
      end
    end
  end

  # ─── validate! ────────────────────────────────────────────────────────────

  describe ".validate!" do
    it "returns the raw hash unchanged for valid config" do
      raw = { "tracker" => { "base_url" => "https://x.atlassian.net" } }
      expect(described_class.validate!(raw)).to eq(raw)
    end

    it "raises ConfigError for invalid config" do
      expect { described_class.validate!("bad") }
        .to raise_error(Taskmate::ConfigError, /root must be a Hash/)
    end

    it "raises ConfigError listing all errors" do
      raw = { "ai" => { "provider" => "bad" }, "push" => { "allowed_fields" => "x" } }
      expect { described_class.validate!(raw) }
        .to raise_error(Taskmate::ConfigError)
    end
  end
end
