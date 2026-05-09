require "yaml"
require "date"

module Taskmate
  module Workspace
    class FrontmatterFile
      DELIMITER = "---".freeze
      FRONTMATTER_REGEX = /\A---\r?\n(.*?)\r?\n---\r?\n?(.*)\z/m

      attr_reader :frontmatter, :body, :raw_content

      def self.parse(content)
        raise InvalidFrontmatterError, "File has no frontmatter delimiter" unless content.start_with?("---")

        match = FRONTMATTER_REGEX.match(content)
        raise InvalidFrontmatterError, "Malformed frontmatter: missing closing ---" unless match

        yaml_str = match[1]
        body     = match[2].to_s

        begin
          fm = YAML.safe_load(yaml_str, permitted_classes: [Symbol, Date, Time])
        rescue Psych::Exception => e
          raise InvalidFrontmatterError, "Invalid YAML in frontmatter: #{e.message}"
        end

        raise InvalidFrontmatterError, "Frontmatter must be a YAML mapping" unless fm.is_a?(Hash)

        new(frontmatter: fm, body: body, raw_content: content)
      end

      def self.serialize(frontmatter, body)
        fm_yaml = YAML.dump(frontmatter).sub(/\A---\n/, "")
        "---\n#{fm_yaml}---\n#{body}"
      end

      def initialize(frontmatter:, body:, raw_content: nil)
        @frontmatter = frontmatter
        @body        = body.to_s
        @raw_content = raw_content || self.class.serialize(frontmatter, body)
      end

      def serialize
        self.class.serialize(@frontmatter, @body)
      end

      def ==(other)
        other.is_a?(FrontmatterFile) &&
          frontmatter == other.frontmatter &&
          body == other.body
      end
    end
  end
end
