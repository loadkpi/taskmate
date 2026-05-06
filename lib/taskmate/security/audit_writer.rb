require "yaml"
require "securerandom"
require "digest"
require "fileutils"

module Taskmate
  module Security
    class AuditWriter
      def initialize(workspace_path:)
        @workspace_path = workspace_path
      end

      # Write an action audit entry (Jira write)
      #
      # @param fields_changed  [Array<String>]
      # @param user_confirmed  [Boolean]
      # @param dry_run         [Boolean]
      # @param issue_key       [String, nil]
      # @param warnings        [Array<String>]
      def write_action_audit(fields_changed:, user_confirmed:, dry_run: false,
                             issue_key: nil, warnings: [])
        entry = {
          "type"           => "action_audit",
          "timestamp"      => timestamp_ms,
          "issue_key"      => issue_key,
          "fields_changed" => fields_changed,
          "user_confirmed" => user_confirmed,
          "dry_run"        => dry_run,
          "warnings"       => warnings
        }
        write_to("audit/actions", entry)
      end

      # Write an AI call audit entry
      #
      # @param skill       [String]
      # @param provider    [String]
      # @param model       [String]
      # @param prompt_hash [String]  SHA-256 of the prompt (never the raw prompt)
      # @param issue_key   [String, nil]
      def write_ai_audit(skill:, provider:, model:, prompt_hash:, issue_key: nil)
        entry = {
          "type"        => "ai_call_audit",
          "timestamp"   => timestamp_ms,
          "issue_key"   => issue_key,
          "skill"       => skill,
          "provider"    => provider,
          "model"       => model,
          "prompt_hash" => prompt_hash
        }
        write_to("audit/ai", entry)
      end

      # Compute a safe prompt hash without storing the raw prompt
      def self.prompt_hash(prompt_text)
        "sha256:#{Digest::SHA256.hexdigest(prompt_text.to_s)}"
      end

      private

      def timestamp_ms
        (Time.now.to_f * 1000).to_i
      end

      def write_to(subdir, entry)
        dir  = File.join(@workspace_path, subdir)
        FileUtils.mkdir_p(dir)
        name = "#{entry["timestamp"]}-#{subdir.split("/").last}-#{SecureRandom.hex(4)}.yml"
        path = File.join(dir, name)
        File.write(path, YAML.dump(entry), encoding: "utf-8")
        path
      end
    end
  end
end
