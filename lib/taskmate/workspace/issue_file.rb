require "securerandom"
require "taskmate/workspace/frontmatter_file"

module Taskmate
  module Workspace
    class IssueFile
      attr_accessor :path, :frontmatter, :body

      def self.read(path)
        raise IssueNotFoundError, "Issue file not found: #{path}" unless File.exist?(path)

        content = File.read(path, encoding: "utf-8")
        ff = FrontmatterFile.parse(content)
        new(path: path, frontmatter: ff.frontmatter, body: ff.body)
      end

      def self.build(frontmatter:, body:, path: nil)
        new(path: path, frontmatter: frontmatter, body: body)
      end

      def initialize(path:, frontmatter:, body:)
        @path        = path
        @frontmatter = stringify_keys(frontmatter)
        @body        = body.to_s
      end

      # Frontmatter accessors

      def key
        frontmatter["key"]
      end

      def key=(val)
        frontmatter["key"] = val
      end

      def summary
        frontmatter["summary"]
      end

      def issue_type
        frontmatter["issue_type"]
      end

      def status
        frontmatter["status"]
      end

      def priority
        frontmatter["priority"]
      end

      def labels
        Array(frontmatter["labels"])
      end

      def components
        Array(frontmatter["components"])
      end

      def story_points
        frontmatter["story_points"]
      end

      def due_date
        frontmatter["due_date"]
      end

      def tracker
        frontmatter["tracker"] || "jira"
      end

      def project
        return nil if key.nil?

        key.split("-").first
      end

      def assignee
        StructuredUser.from(frontmatter["assignee"])
      end

      def reporter
        StructuredUser.from(frontmatter["reporter"])
      end

      def sync_state
        frontmatter["sync_state"]
      end

      def sync_state=(val)
        frontmatter["sync_state"] = val
      end

      def last_synced_local_hash
        frontmatter["last_synced_local_hash"]
      end

      def last_synced_local_hash=(val)
        frontmatter["last_synced_local_hash"] = val
      end

      def jira_source_hash
        frontmatter["jira_source_hash"]
      end

      def jira_source_hash=(val)
        frontmatter["jira_source_hash"] = val
      end

      def last_pulled_at
        frontmatter["last_pulled_at"]
      end

      def last_pulled_at=(val)
        frontmatter["last_pulled_at"] = val
      end

      # Type helpers

      def new_local?
        key.nil?
      end

      def existing?
        !new_local?
      end

      # Persistence

      def write(dest_path = @path)
        raise ArgumentError, "No path specified for IssueFile#write" if dest_path.nil?

        @path = dest_path
        content = FrontmatterFile.serialize(frontmatter, body)

        # Atomic write: temp file + rename
        tmp = "#{dest_path}.tmp.#{Process.pid}.#{SecureRandom.hex(4)}"
        File.write(tmp, content, encoding: "utf-8")
        File.rename(tmp, dest_path)
      end

      def default_path(workspace_path)
        if new_local?
          slug = summary.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
          date = Time.now.strftime("%Y-%m-%d")
          File.join(workspace_path, "issues", "new", "#{date}-#{slug}.md")
        else
          File.join(workspace_path, "issues", "#{key}.md")
        end
      end

      def raw_content
        FrontmatterFile.serialize(frontmatter, body)
      end

      # StructuredUser for assignee/reporter
      StructuredUser = Struct.new(:account_id, :display_name, :email, keyword_init: true) do
        def self.from(data)
          return nil if data.nil?
          return new(account_id: nil, display_name: data.to_s, email: nil) unless data.is_a?(Hash)

          new(
            account_id: data["account_id"],
            display_name: data["display_name"],
            email: data["email"]
          )
        end
      end

      private

      def stringify_keys(obj)
        case obj
        when Hash
          obj.transform_keys(&:to_s).transform_values { |v| stringify_keys(v) }
        when Array
          obj.map { |v| stringify_keys(v) }
        else
          obj
        end
      end
    end
  end
end
