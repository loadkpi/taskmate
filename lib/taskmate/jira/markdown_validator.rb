module Taskmate
  module Jira
    class MarkdownValidator
      ValidationError = Struct.new(:feature, :line_number, :message, keyword_init: true)

      # Patterns for unsupported Markdown features
      UNSUPPORTED = [
        { pattern: /^!\[/,         feature: "image",          message: "Images are not supported" },
        { pattern: /^\|/,           feature: "table",          message: "Tables are not supported" },
        { pattern: /^={2,}\s*$/,    feature: "setext_heading", message: "Setext-style headings (===) are not supported" },
        { pattern: /^-+\s*$/,       feature: "setext_heading", message: "Setext-style headings (---) as header is not supported" },
        { pattern: /^\s{4}/,        feature: "indented_code",  message: "Indented code blocks (4 spaces) are not supported; use fenced ``` blocks" },
        { pattern: /^<[a-z]/i,      feature: "html",           message: "Inline HTML is not supported" },
        { pattern: /^\[.+\]:/,      feature: "link_ref",       message: "Reference-style links are not supported" },
        { pattern: /^>\s/,          feature: "blockquote",     message: "Blockquotes are not supported" },
        { pattern: /~~/,            feature: "strikethrough",  message: "Strikethrough (~~ ~~) is not supported" }
      ].freeze

      def validate(markdown)
        errors = []
        in_code_block = false
        prev_line = ""

        markdown.to_s.lines.each_with_index do |line, idx|
          line = line.chomp
          line_num = idx + 1

          # Toggle code block state
          if line.start_with?("```")
            in_code_block = !in_code_block
            prev_line = line
            next
          end

          if in_code_block
            prev_line = line
            next
          end

          UNSUPPORTED.each do |rule|
            next unless rule[:pattern].match?(line)

            if rule[:feature] == "setext_heading"
              # A dash-only line is a setext heading underline only when it follows
              # a non-blank text line. Otherwise it is a thematic break — allow it.
              next if prev_line.strip.empty?
            end

            errors << ValidationError.new(
              feature:     rule[:feature],
              line_number: line_num,
              message:     rule[:message]
            )
          end

          prev_line = line
        end

        errors
      end

      def valid?(markdown)
        validate(markdown).empty?
      end
    end
  end
end
