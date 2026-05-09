require "digest"
require "json"

module Taskmate
  module Workspace
    class CanonicalHash
      HASHED_FIELDS = %w[
        summary issue_type priority labels components story_points due_date
      ].freeze

      def self.compute(frontmatter:, body:)
        canonical = build_canonical(frontmatter, body)
        "sha256:#{Digest::SHA256.hexdigest(canonical)}"
      end

      def self.compute_for(issue_file)
        compute(frontmatter: issue_file.frontmatter, body: issue_file.body)
      end

      def self.build_canonical(frontmatter, body)
        selected = HASHED_FIELDS.each_with_object({}) do |field, h|
          val = frontmatter[field]
          next if val.nil?

          # Sort primitive arrays for determinism; leave complex arrays as-is
          h[field] = val.is_a?(Array) && val.all? { |e| e.is_a?(String) || e.is_a?(Numeric) } ? val.sort : val
        end

        normalized_body = body.to_s.gsub("\r\n", "\n").strip

        JSON.generate({ "fields" => selected, "body" => normalized_body })
      end

      private_class_method :build_canonical
    end
  end
end
