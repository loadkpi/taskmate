require "spec_helper"
require "taskmate/config"

RSpec.describe Taskmate::Config::Loader do
  let(:workspace) { create_temp_workspace }

  def write_workspace_yml(content)
    File.write(File.join(workspace, "workspace.yml"), content)
  end

  # ─── load_raw ─────────────────────────────────────────────────────────────

  describe ".load_raw" do
    it "returns :not_found when workspace.yml is absent" do
      expect(described_class.load_raw(workspace)).to eq(:not_found)
    end

    it "returns :invalid_yaml when workspace.yml is malformed YAML" do
      write_workspace_yml("foo: [unclosed")
      expect(described_class.load_raw(workspace)).to eq(:invalid_yaml)
    end

    it "returns :invalid_structure when workspace.yml root is not a Hash" do
      write_workspace_yml("- item1\n- item2\n")
      expect(described_class.load_raw(workspace)).to eq(:invalid_structure)
    end

    it "returns a Hash for valid workspace.yml" do
      write_workspace_yml("tracker:\n  base_url: https://example.atlassian.net\n")
      result = described_class.load_raw(workspace)
      expect(result).to be_a(Hash)
      expect(result.dig("tracker", "base_url")).to eq("https://example.atlassian.net")
    end
  end

  # ─── load ─────────────────────────────────────────────────────────────────

  describe ".load" do
    context "with no workspace.yml" do
      it "raises ConfigError with a helpful message" do
        expect { described_class.load(workspace, env: {}) }
          .to raise_error(Taskmate::ConfigError, /workspace\.yml not found.*taskmate init/i)
      end
    end

    context "with a minimal valid workspace.yml" do
      subject(:cfg) { described_class.load(workspace, env: {}) }

      before { write_workspace_yml("---\n{}\n") }

      it "returns an AppConfig" do
        expect(cfg).to be_a(Taskmate::Config::AppConfig)
      end

      it "sets empty tracker base_url by default" do
        expect(cfg.tracker.base_url).to eq("")
      end

      it "sets ai.provider to disabled by default" do
        expect(cfg.ai.provider).to eq("disabled")
      end

      it "sets security defaults to true" do
        expect(cfg.security.require_consent_for_ai).to be(true)
        expect(cfg.security.require_confirm_for_push).to be(true)
        expect(cfg.security.secret_detection).to be(true)
      end

      it "sets push.allowed_fields to standard fields by default" do
        expect(cfg.push.allowed_fields).to eq(%w[summary description labels components priority])
      end

      it "sets empty auth credentials" do
        expect(cfg.auth.email).to eq("")
        expect(cfg.auth.api_token).to eq("")
      end
    end

    context "with workspace.yml containing tracker config" do
      subject(:cfg) { described_class.load(workspace, env: {}) }

      before do
        write_workspace_yml(<<~YAML)
          tracker:
            base_url: https://mycompany.atlassian.net
            default_project: PROJ
            story_points_field: customfield_10028
        YAML
      end

      it "reads tracker.base_url" do
        expect(cfg.tracker.base_url).to eq("https://mycompany.atlassian.net")
      end

      it "reads tracker.default_project" do
        expect(cfg.tracker.default_project).to eq("PROJ")
      end

      it "reads tracker.story_points_field" do
        expect(cfg.tracker.story_points_field).to eq("customfield_10028")
      end
    end

    context "with ENV overrides" do
      before do
        write_workspace_yml("tracker:\n  base_url: https://yml.atlassian.net\n")
      end

      it "ENV TASKMATE_JIRA_URL overrides tracker.base_url" do
        cfg = described_class.load(workspace, env: { "TASKMATE_JIRA_URL" => "https://env.atlassian.net" })
        expect(cfg.tracker.base_url).to eq("https://env.atlassian.net")
      end

      it "ENV TASKMATE_JIRA_EMAIL populates auth.email" do
        cfg = described_class.load(workspace, env: { "TASKMATE_JIRA_EMAIL" => "user@example.com" })
        expect(cfg.auth.email).to eq("user@example.com")
      end

      it "ENV TASKMATE_JIRA_TOKEN populates auth.api_token" do
        cfg = described_class.load(workspace, env: { "TASKMATE_JIRA_TOKEN" => "secret" })
        expect(cfg.auth.api_token).to eq("secret")
      end

      it "ENV TASKMATE_AI_PROVIDER overrides ai.provider" do
        cfg = described_class.load(workspace, env: { "TASKMATE_AI_PROVIDER" => "openai" })
        expect(cfg.ai.provider).to eq("openai")
      end

      it "ENV TASKMATE_AI_MODEL overrides ai.model" do
        cfg = described_class.load(workspace, env: { "TASKMATE_AI_MODEL" => "gpt-4o" })
        expect(cfg.ai.model).to eq("gpt-4o")
      end
    end

    context "with legacy jira.* keys in workspace.yml" do
      subject(:cfg) { described_class.load(workspace, env: {}) }

      before do
        write_workspace_yml(<<~YAML)
          jira:
            base_url: https://legacy.atlassian.net
            default_project: LEG
            story_points_field: customfield_99
        YAML
      end

      it "falls back to jira.base_url when tracker.base_url is absent" do
        expect(cfg.tracker.base_url).to eq("https://legacy.atlassian.net")
      end

      it "falls back to jira.default_project" do
        expect(cfg.tracker.default_project).to eq("LEG")
      end

      it "falls back to jira.story_points_field" do
        expect(cfg.tracker.story_points_field).to eq("customfield_99")
      end
    end

    context "with ai config" do
      subject(:cfg) { described_class.load(workspace, env: {}) }

      before do
        write_workspace_yml(<<~YAML)
          ai:
            provider: anthropic
            model: claude-sonnet-4-6
            enabled: true
        YAML
      end

      it "reads ai.provider" do
        expect(cfg.ai.provider).to eq("anthropic")
      end

      it "reads ai.model" do
        expect(cfg.ai.model).to eq("claude-sonnet-4-6")
      end

      it "reads ai.enabled" do
        expect(cfg.ai.enabled).to be(true)
      end
    end

    context "with push.allowed_fields configured" do
      subject(:cfg) { described_class.load(workspace, env: {}) }

      before do
        write_workspace_yml(<<~YAML)
          push:
            allowed_fields:
              - summary
              - description
        YAML
      end

      it "reads push.allowed_fields" do
        expect(cfg.push.allowed_fields).to eq(%w[summary description])
      end
    end

    context "with security section" do
      subject(:cfg) { described_class.load(workspace, env: {}) }

      before do
        write_workspace_yml(<<~YAML)
          security:
            require_consent_for_ai: false
            require_confirm_for_push: true
            secret_detection: false
        YAML
      end

      it "reads security flags" do
        expect(cfg.security.require_consent_for_ai).to be(false)
        expect(cfg.security.require_confirm_for_push).to be(true)
        expect(cfg.security.secret_detection).to be(false)
      end
    end

    context "with legacy ai.default_provider key" do
      subject(:cfg) { described_class.load(workspace, env: {}) }

      before do
        write_workspace_yml(<<~YAML)
          ai:
            default_provider: openai
            default_model: gpt-4o
        YAML
      end

      it "falls back to ai.default_provider" do
        expect(cfg.ai.provider).to eq("openai")
      end

      it "falls back to ai.default_model" do
        expect(cfg.ai.model).to eq("gpt-4o")
      end
    end

    context "when workspace.yml has invalid YAML" do
      before { write_workspace_yml("foo: [unclosed") }

      it "raises ConfigError" do
        expect { described_class.load(workspace, env: {}) }
          .to raise_error(Taskmate::ConfigError, /invalid YAML/i)
      end
    end

    context "when workspace.yml root is not a Hash" do
      before { write_workspace_yml("- item1\n- item2\n") }

      it "raises ConfigError" do
        expect { described_class.load(workspace, env: {}) }
          .to raise_error(Taskmate::ConfigError, /must be a Hash/i)
      end
    end

    context "when workspace.yml has invalid config values" do
      before do
        write_workspace_yml(<<~YAML)
          ai:
            provider: badprovider
        YAML
      end

      it "raises ConfigError with validation details" do
        expect { described_class.load(workspace, env: {}) }
          .to raise_error(Taskmate::ConfigError, /ai\.provider.*invalid/i)
      end
    end
  end
end
