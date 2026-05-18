require "spec_helper"
require "taskmate/ai/client"
require "taskmate/config"

RSpec.describe Taskmate::AI::Client do
  def make_app_config(provider: "disabled", model: nil, enabled: true)
    ai_cfg = Taskmate::Config::AiConfig.new(provider: provider, model: model, enabled: enabled)
    Taskmate::Config::AppConfig.new(
      ai: ai_cfg,
      tracker: Taskmate::Config::TrackerConfig.new(base_url: "", default_project: "", story_points_field: nil),
      auth: Taskmate::Config::JiraAuthConfig.new(email: "", api_token: ""),
      security: Taskmate::Config::SecurityConfig.new(
        require_consent_for_ai: true, require_confirm_for_push: true, secret_detection: true
      ),
      push: Taskmate::Config::PushConfig.new(allowed_fields: [])
    )
  end

  describe ".from_app_config" do
    it "returns FakeProvider when ai.enabled is false" do
      cfg      = make_app_config(provider: "anthropic", enabled: false)
      provider = described_class.from_app_config(cfg)
      expect(provider).to be_a(Taskmate::AI::Providers::FakeProvider)
    end

    it "returns FakeProvider when provider is 'disabled'" do
      cfg      = make_app_config(provider: "disabled")
      provider = described_class.from_app_config(cfg)
      expect(provider).to be_a(Taskmate::AI::Providers::FakeProvider)
    end

    it "returns FakeProvider when provider is empty" do
      cfg      = make_app_config(provider: "")
      provider = described_class.from_app_config(cfg)
      expect(provider).to be_a(Taskmate::AI::Providers::FakeProvider)
    end

    it "builds a FakeProvider for the fake provider" do
      cfg      = make_app_config(provider: "fake")
      provider = described_class.from_app_config(cfg)
      expect(provider).to be_a(Taskmate::AI::Providers::FakeProvider)
    end

    it "raises ValidationError for unknown provider" do
      cfg = make_app_config(provider: "unknown_provider")
      expect { described_class.from_app_config(cfg) }
        .to raise_error(Taskmate::ValidationError, /Unknown AI provider/)
    end
  end
end
