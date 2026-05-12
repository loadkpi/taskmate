module Taskmate
  module Workspace
    class IgnoreRules
      def initialize(rules_content = "")
        @patterns = parse(rules_content.to_s)
      end

      def self.load(workspace_path)
        path = File.join(workspace_path, ".taskmateignore")
        content = File.exist?(path) ? File.read(path, encoding: "utf-8") : ""
        new(content)
      end

      def ignored?(path)
        basename = File.basename(path)
        relative = path.to_s

        @patterns.any? do |pattern|
          match?(pattern, relative, basename)
        end
      end

      private

      def parse(content)
        content.each_line.filter_map do |line|
          line = line.chomp
          next if line.empty? || line.start_with?("#")

          line
        end
      end

      def match?(pattern, path, basename)
        if pattern.end_with?("/")
          # Directory pattern: path must start with or contain the directory prefix
          # "attachments/" matches "attachments/file.pdf" but NOT "attachments"
          # "issues/private/" matches "issues/private/SAR-1.md"
          dir_prefix = pattern.chomp("/")
          path.start_with?("#{dir_prefix}/") || path.include?("/#{dir_prefix}/")
        elsif pattern.include?("/")
          File.fnmatch(pattern, path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        else
          # Basename glob
          File.fnmatch(pattern, basename, File::FNM_DOTMATCH)
        end
      end
    end
  end
end
