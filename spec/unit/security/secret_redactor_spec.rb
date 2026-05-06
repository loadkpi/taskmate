require "spec_helper"
require "taskmate/security/secret_redactor"

RSpec.describe Taskmate::Security::SecretRedactor do
  subject(:redactor) { described_class.new }

  SAFE_TEXT = <<~TEXT
    Fixed a bug in the login flow. The issue was caused by a missing nil-check
    in the session cookie handler. Tests were added to verify the fix.
    See https://example.com/docs for more context.
  TEXT

  describe "#secrets_found?" do
    context "with safe text" do
      it "returns false for ordinary issue descriptions" do
        expect(redactor.secrets_found?(SAFE_TEXT)).to be(false)
      end

      it "returns false for nil" do
        expect(redactor.secrets_found?(nil)).to be(false)
      end

      it "returns false for empty string" do
        expect(redactor.secrets_found?("")).to be(false)
      end
    end

    context "with JWT tokens" do
      it "detects Bearer + JWT" do
        text = "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.abc123def456"
        expect(redactor.secrets_found?(text)).to be(true)
      end

      it "detects standalone JWT" do
        text = "token=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyMTIzIn0.SflKxwRJSMeKKF2QT4fwpMeJf36"
        expect(redactor.secrets_found?(text)).to be(true)
      end
    end

    context "with AWS keys" do
      it "detects AKIA access key IDs" do
        text = "aws_access_key_id = AKIAIOSFODNN7EXAMPLE"
        expect(redactor.secrets_found?(text)).to be(true)
      end

      it "detects AWS secret in key=value context" do
        text = "aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY00"
        expect(redactor.secrets_found?(text)).to be(true)
      end
    end

    context "with GitHub tokens" do
      it "detects ghp_ tokens" do
        text = "GITHUB_TOKEN=ghp_16C7e42F292c6912E7710c838347Ae178B4a"
        expect(redactor.secrets_found?(text)).to be(true)
      end

      it "detects ghs_ tokens" do
        text = "token: ghs_16C7e42F292c6912E7710c838347Ae178B4a"
        expect(redactor.secrets_found?(text)).to be(true)
      end
    end

    context "with GitLab tokens" do
      it "detects glpat- tokens" do
        text = "token=glpat-xxxxxxxxxxxxxxxxxxxx"
        expect(redactor.secrets_found?(text)).to be(true)
      end
    end

    context "with private keys" do
      it "detects RSA private key header" do
        text = "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA..."
        expect(redactor.secrets_found?(text)).to be(true)
      end

      it "detects generic private key header" do
        text = "-----BEGIN PRIVATE KEY-----"
        expect(redactor.secrets_found?(text)).to be(true)
      end

      it "detects PGP private key header" do
        text = "-----BEGIN PGP PRIVATE KEY BLOCK-----"
        expect(redactor.secrets_found?(text)).to be(true)
      end
    end

    context "with URL credentials" do
      it "detects https://user:pass@host URLs" do
        text = "repo: https://alice:s3cr3t@github.com/org/repo.git"
        expect(redactor.secrets_found?(text)).to be(true)
      end
    end

    context "with generic secrets" do
      it "detects password=... patterns" do
        text = "password=mysecretpassword123"
        expect(redactor.secrets_found?(text)).to be(true)
      end

      it "detects api_key=... patterns" do
        text = "api_key: abcdef1234567890"
        expect(redactor.secrets_found?(text)).to be(true)
      end
    end
  end

  describe "#redact" do
    it "replaces JWT Bearer token with [REDACTED]" do
      text   = "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.abc123def456"
      result = redactor.redact(text)
      expect(result).to include("[REDACTED]")
      expect(result).not_to include("eyJhbGciOiJIUzI1NiJ9")
    end

    it "replaces AKIA key with [REDACTED]" do
      text   = "key: AKIAIOSFODNN7EXAMPLE"
      result = redactor.redact(text)
      expect(result).to include("[REDACTED]")
      expect(result).not_to include("AKIA")
    end

    it "replaces URL credentials with [REDACTED]" do
      text   = "clone https://alice:s3cr3t@github.com/org/repo.git"
      result = redactor.redact(text)
      expect(result).to include("[REDACTED]")
      expect(result).not_to include("s3cr3t")
    end

    it "leaves non-secret text unchanged" do
      result = redactor.redact(SAFE_TEXT)
      expect(result).to eq(SAFE_TEXT)
    end

    it "returns empty string for nil input" do
      expect(redactor.redact(nil)).to eq("")
    end
  end

  describe "#scan" do
    it "returns empty array for safe text" do
      expect(redactor.scan(SAFE_TEXT)).to be_empty
    end

    it "returns SecretMatch structs" do
      text    = "key: AKIAIOSFODNN7EXAMPLE"
      matches = redactor.scan(text)
      expect(matches).not_to be_empty
      m = matches.first
      expect(m).to respond_to(:type)
      expect(m).to respond_to(:position)
      expect(m).to respond_to(:severity)
    end

    it "reports :aws_key type for AKIA keys" do
      text    = "AKIAIOSFODNN7EXAMPLE"
      matches = redactor.scan(text)
      expect(matches.map(&:type)).to include(:aws_key)
    end

    it "reports :critical severity for private keys" do
      text    = "-----BEGIN RSA PRIVATE KEY-----"
      matches = redactor.scan(text)
      expect(matches.first.severity).to eq(:critical)
    end
  end

  describe "false positive rate" do
    TYPICAL_ISSUE_BODIES = [
      "The button is misaligned on mobile. CSS fix needed.",
      "After the migration, users see a 500 error. Stack trace attached.",
      "API endpoint returns 401 when token is missing. Expected 403.",
      "Update the README with setup instructions and example commands.",
      "Refactor the auth module to use a service pattern instead of helpers."
    ].freeze

    it "has no false positives on typical issue descriptions" do
      false_positives = TYPICAL_ISSUE_BODIES.count { |body| redactor.secrets_found?(body) }
      rate = false_positives.to_f / TYPICAL_ISSUE_BODIES.size
      expect(rate).to be < 0.05
    end
  end
end
