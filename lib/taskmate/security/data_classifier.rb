require "taskmate/security/secret_redactor"
require "taskmate/workspace/ignore_rules"

module Taskmate
  module Security
    class DataClassifier
      Classification = Struct.new(:level, :sections, :excluded_paths, keyword_init: true)
      Section        = Struct.new(:name, :content, :level, keyword_init: true)

      LEVELS = %i[safe sensitive secret].freeze

      def initialize(workspace_path:, ignore_rules: nil, redactor: nil)
        @workspace_path = workspace_path
        @ignore_rules   = ignore_rules || Workspace::IgnoreRules.load(workspace_path)
        @redactor       = redactor || SecretRedactor.new
      end

      def classify(issue_file)
        relative_path = relative_path_for(issue_file)

        if @ignore_rules.ignored?(relative_path.to_s)
          return Classification.new(
            level: :excluded,
            sections: [],
            excluded_paths: [relative_path]
          )
        end

        sections = classify_sections(issue_file)
        max_level = highest_level(sections.map(&:level))

        Classification.new(
          level: max_level,
          sections: sections,
          excluded_paths: []
        )
      end

      private

      def relative_path_for(issue_file)
        return issue_file.path.to_s if @workspace_path.nil? || issue_file.path.nil?

        abs_path = File.expand_path(issue_file.path.to_s)
        abs_base = File.expand_path(@workspace_path.to_s)
        prefix   = "#{abs_base}/"
        abs_path.start_with?(prefix) ? abs_path.delete_prefix(prefix) : abs_path
      end

      def classify_sections(issue_file)
        sections = []

        # Classify body
        sections << Section.new(
          name: "body",
          content: issue_file.body,
          level: level_for(issue_file.body)
        )

        # Classify key frontmatter fields that might contain sensitive content
        %w[summary description].each do |field|
          val = issue_file.frontmatter[field].to_s
          next if val.empty?

          sections << Section.new(
            name: field,
            content: val,
            level: level_for(val)
          )
        end

        sections
      end

      def level_for(text)
        return :safe if text.nil? || text.empty?
        return :secret if @redactor.secrets_found?(text)

        sensitive?(text) ? :sensitive : :safe
      end

      def sensitive?(text)
        # Heuristic: contains words suggesting sensitive info but not outright secrets
        /\b(?:password|credential|secret|private|confidential|internal|ssn|passport)\b/i.match?(text)
      end

      def highest_level(levels)
        LEVELS.reverse.find { |l| levels.include?(l) } || :safe
      end
    end
  end
end
