require "spec_helper"
require "taskmate/jira/client"

RSpec.describe Taskmate::Jira::Client do
  subject(:client) do
    described_class.new(base_url: "https://test.atlassian.net",
                        email: "user@test.com", api_token: "token",
                        max_retries: 0)
  end

  def stub_get(path, status:, body:)
    stubs = Faraday::Adapter::Test::Stubs.new do |s|
      s.get(path) { [status, { "Content-Type" => "application/json" }, body] }
    end
    client.instance_variable_set(:@conn, Faraday.new { |f| f.adapter :test, stubs })
  end

  def stub_get_error(path, error)
    stubs = Faraday::Adapter::Test::Stubs.new do |s|
      s.get(path) { raise error }
    end
    client.instance_variable_set(:@conn, Faraday.new { |f| f.adapter :test, stubs })
  end

  def stub_write(method, path, status:, body:)
    stubs = Faraday::Adapter::Test::Stubs.new do |s|
      s.public_send(method, path) { [status, { "Content-Type" => "application/json" }, body] }
    end
    client.instance_variable_set(:@write_conn, Faraday.new { |f| f.adapter :test, stubs })
  end

  def stub_write_error(method, path, error)
    stubs = Faraday::Adapter::Test::Stubs.new do |s|
      s.public_send(method, path) { raise error }
    end
    client.instance_variable_set(:@write_conn, Faraday.new { |f| f.adapter :test, stubs })
  end

  describe "#find_issue" do
    it "returns parsed JSON on 200" do
      stub_get("/rest/api/3/issue/TEST-1", status: 200, body: '{"key":"TEST-1"}')
      expect(client.find_issue("TEST-1")).to eq("key" => "TEST-1")
    end

    it "raises JiraAuthError on 401" do
      stub_get("/rest/api/3/issue/TEST-1", status: 401, body: "Unauthorized")
      expect { client.find_issue("TEST-1") }.to raise_error(Taskmate::JiraAuthError, /401/)
    end

    it "raises JiraAuthError on 403" do
      stub_get("/rest/api/3/issue/TEST-1", status: 403, body: "Forbidden")
      expect { client.find_issue("TEST-1") }.to raise_error(Taskmate::JiraAuthError, /403/)
    end

    it "raises JiraNotFoundError on 404" do
      stub_get("/rest/api/3/issue/TEST-1", status: 404, body: "Not Found")
      expect { client.find_issue("TEST-1") }.to raise_error(Taskmate::JiraNotFoundError)
    end

    it "raises JiraRateLimitError on 429" do
      stub_get("/rest/api/3/issue/TEST-1", status: 429, body: "Too Many Requests")
      expect { client.find_issue("TEST-1") }.to raise_error(Taskmate::JiraRateLimitError)
    end

    it "raises JiraError on 500" do
      stub_get("/rest/api/3/issue/TEST-1", status: 500, body: "Internal Server Error")
      expect { client.find_issue("TEST-1") }.to raise_error(Taskmate::JiraError, /500/)
    end

    it "raises JiraError on invalid JSON response" do
      stub_get("/rest/api/3/issue/TEST-1", status: 200, body: "not-json{{{")
      expect { client.find_issue("TEST-1") }.to raise_error(Taskmate::JiraError, /invalid JSON/)
    end

    it "raises JiraError on connection failure" do
      stub_get_error("/rest/api/3/issue/TEST-1", Faraday::ConnectionFailed.new("refused"))
      expect { client.find_issue("TEST-1") }.to raise_error(Taskmate::JiraError, /unreachable/)
    end

    it "raises JiraError on timeout" do
      stub_get_error("/rest/api/3/issue/TEST-1", Faraday::TimeoutError.new("timed out"))
      expect { client.find_issue("TEST-1") }.to raise_error(Taskmate::JiraError, /unreachable/)
    end
  end

  describe "#create_issue" do
    let(:payload) { { "fields" => { "summary" => "Test" } } }

    it "returns parsed JSON on 201" do
      stub_write(:post, "/rest/api/3/issue", status: 201, body: '{"key":"TEST-99"}')
      expect(client.create_issue(payload)).to eq("key" => "TEST-99")
    end

    it "raises JiraWriteError on 400" do
      stub_write(:post, "/rest/api/3/issue", status: 400, body: '{"errorMessages":["bad"]}')
      expect { client.create_issue(payload) }.to raise_error(Taskmate::JiraWriteError, /400/)
    end

    it "raises JiraAuthError on 401 write" do
      stub_write(:post, "/rest/api/3/issue", status: 401, body: "Unauthorized")
      expect { client.create_issue(payload) }.to raise_error(Taskmate::JiraAuthError)
    end

    it "raises JiraWriteError on connection failure during write" do
      stub_write_error(:post, "/rest/api/3/issue", Faraday::ConnectionFailed.new("refused"))
      expect { client.create_issue(payload) }
        .to raise_error(Taskmate::JiraWriteError, /timed out or connection lost/)
    end
  end

  describe "#update_issue" do
    let(:payload) { { "fields" => { "summary" => "Updated" } } }

    it "returns empty hash on 204 (no content)" do
      stub_write(:put, "/rest/api/3/issue/TEST-1", status: 204, body: "")
      expect(client.update_issue("TEST-1", payload)).to eq({})
    end

    it "raises JiraWriteError on timeout during write" do
      stub_write_error(:put, "/rest/api/3/issue/TEST-1", Faraday::TimeoutError.new("timed out"))
      expect { client.update_issue("TEST-1", payload) }
        .to raise_error(Taskmate::JiraWriteError, /timed out or connection lost/)
    end
  end
end
