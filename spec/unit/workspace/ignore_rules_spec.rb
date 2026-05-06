require "spec_helper"
require "taskmate/workspace/ignore_rules"

RSpec.describe Taskmate::Workspace::IgnoreRules do
  def rules(content)
    described_class.new(content)
  end

  describe "#ignored?" do
    it "matches *.key wildcard" do
      expect(rules("*.key").ignored?("server.key")).to be(true)
    end

    it "does not match non-matching basename" do
      expect(rules("*.key").ignored?("server.pem")).to be(false)
    end

    it "matches attachments/ directory pattern for files inside" do
      expect(rules("attachments/").ignored?("attachments/file.pdf")).to be(true)
    end

    it "does NOT match plain 'attachments' with attachments/ pattern" do
      expect(rules("attachments/").ignored?("attachments")).to be(false)
    end

    it "matches exact filename" do
      expect(rules("secrets.yml").ignored?("secrets.yml")).to be(true)
    end

    it "does not match different filename" do
      expect(rules("secrets.yml").ignored?("secrets.yaml")).to be(false)
    end

    it "ignores comment lines" do
      expect(rules("# this is a comment\n*.key").ignored?("server.key")).to be(true)
    end

    it "ignores empty lines" do
      expect(rules("\n\n*.key\n\n").ignored?("server.key")).to be(true)
    end

    it "matches dotfiles like .env" do
      expect(rules(".env").ignored?(".env")).to be(true)
    end

    it "matches .env.* wildcard" do
      expect(rules(".env.*").ignored?(".env.local")).to be(true)
    end
  end

  describe ".load" do
    it "returns empty rules if .taskmateignore missing" do
      dir = Dir.mktmpdir
      ir = described_class.load(dir)
      expect(ir.ignored?("anything.key")).to be(false)
      FileUtils.rm_rf(dir)
    end

    it "loads rules from file" do
      dir = Dir.mktmpdir
      File.write(File.join(dir, ".taskmateignore"), "*.key\n")
      ir = described_class.load(dir)
      expect(ir.ignored?("server.key")).to be(true)
      FileUtils.rm_rf(dir)
    end
  end
end
