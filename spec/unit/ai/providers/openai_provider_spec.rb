require "spec_helper"
require "taskmate/ai/providers/openai_provider"

RSpec.describe Taskmate::AI::Providers::OpenAiProvider do
  subject(:provider) { described_class.new(api_key: "test-key") }

  def stub_post(path, status:, body:)
    stubs = Faraday::Adapter::Test::Stubs.new do |s|
      s.post(path) { [status, { "Content-Type" => "application/json" }, body] }
    end
    provider.instance_variable_set(:@conn, Faraday.new { |f| f.adapter :test, stubs })
  end

  def stub_post_error(path, error)
    stubs = Faraday::Adapter::Test::Stubs.new do |s|
      s.post(path) { raise error }
    end
    provider.instance_variable_set(:@conn, Faraday.new { |f| f.adapter :test, stubs })
  end

  def without_env(key)
    old = ENV.delete(key)
    yield
  ensure
    ENV[key] = old if old
  end

  describe "#complete" do
    let(:success_body) do
      JSON.generate({ "choices" => [{ "message" => { "content" => "AI result" } }] })
    end

    it "returns extracted content on 200" do
      stub_post("/v1/chat/completions", status: 200, body: success_body)
      expect(provider.complete(prompt: "Do something", skill_id: "test")).to eq("AI result")
    end

    it "raises AiAuthError on 401" do
      stub_post("/v1/chat/completions", status: 401, body: '{"error":"unauthorized"}')
      expect { provider.complete(prompt: "p", skill_id: "s") }
        .to raise_error(Taskmate::AiAuthError, /authentication failed/)
    end

    it "raises AiAuthError on 403" do
      stub_post("/v1/chat/completions", status: 403, body: '{"error":"forbidden"}')
      expect { provider.complete(prompt: "p", skill_id: "s") }
        .to raise_error(Taskmate::AiAuthError)
    end

    it "raises AiProviderError on 429 rate limit" do
      stub_post("/v1/chat/completions", status: 429, body: '{"error":"rate limited"}')
      expect { provider.complete(prompt: "p", skill_id: "s") }
        .to raise_error(Taskmate::AiProviderError, /rate limit/)
    end

    it "raises AiProviderError on 500" do
      stub_post("/v1/chat/completions", status: 500, body: "Internal Server Error")
      expect { provider.complete(prompt: "p", skill_id: "s") }
        .to raise_error(Taskmate::AiProviderError, /500/)
    end

    it "raises AiProviderError on invalid JSON response" do
      stub_post("/v1/chat/completions", status: 200, body: "not-json{{{")
      expect { provider.complete(prompt: "p", skill_id: "s") }
        .to raise_error(Taskmate::AiProviderError, /invalid JSON/)
    end

    it "raises AiProviderError on connection failure" do
      stub_post_error("/v1/chat/completions", Faraday::ConnectionFailed.new("refused"))
      expect { provider.complete(prompt: "p", skill_id: "s") }
        .to raise_error(Taskmate::AiProviderError, /unreachable/)
    end

    it "raises AiProviderError on timeout" do
      stub_post_error("/v1/chat/completions", Faraday::TimeoutError.new("timed out"))
      expect { provider.complete(prompt: "p", skill_id: "s") }
        .to raise_error(Taskmate::AiProviderError, /timed out/)
    end
  end

  describe "initialization" do
    it "raises AiAuthError when API key env var is absent" do
      without_env("TASKMATE_OPENAI_API_KEY") do
        expect { described_class.new }
          .to raise_error(Taskmate::AiAuthError, /TASKMATE_OPENAI_API_KEY/)
      end
    end
  end
end
