module Taskmate
  module Jira
    class AdfToMarkdown
      ConversionResult = Struct.new(:markdown, :unsupported_nodes, keyword_init: true)

      def convert(adf)
        @unsupported_nodes = []
        markdown = render_node(adf || {})
        ConversionResult.new(
          markdown: markdown,
          unsupported_nodes: @unsupported_nodes.uniq
        )
      end

      private

      def render_node(node)
        return "" if node.nil? || node.empty?

        case node["type"]
        when "doc", "listItem"
          render_children(node, separator: "\n")
        when "paragraph"
          content = render_children(node)
          content.empty? ? "" : "#{content}\n"
        when "heading"
          level   = node.dig("attrs", "level") || 1
          prefix  = "#" * [level, 6].min
          "#{prefix} #{render_children(node)}\n"
        when "bulletList"
          render_list(node, ordered: false)
        when "orderedList"
          render_list(node, ordered: true)
        when "codeBlock"
          lang = node.dig("attrs", "language") || ""
          code = render_children(node)
          code = "#{code}\n" unless code.end_with?("\n")
          "```#{lang}\n#{code}```\n"
        when "hardBreak"
          "\n"
        when "text"
          apply_marks(node["text"].to_s, Array(node["marks"]))
        when "blockquote"
          render_children(node, separator: "\n")
            .each_line.map { |l| "> #{l}" }.join
        when "rule"
          "---\n"
        when "mediaSingle", "media", "table", "tableRow", "tableHeader", "tableCell",
             "expand", "nestedExpand", "emoji", "mention", "inlineCard", "blockCard",
             "panel"
          type = node["type"]
          @unsupported_nodes << type
          "<!-- taskmate: unsupported_adf_node type=\"#{type}\" -->\n"
        else
          type = node["type"] || "unknown"
          @unsupported_nodes << type
          "<!-- taskmate: unsupported_adf_node type=\"#{type}\" -->\n"
        end
      end

      def render_children(node, separator: "")
        Array(node["content"]).map { |child| render_node(child) }.join(separator)
      end

      def render_list(node, ordered:)
        items = Array(node["content"]).each_with_index.map do |item, idx|
          bullet  = ordered ? "#{idx + 1}." : "-"
          content = render_node(item).chomp
          # Indent continuation lines for multi-line items
          lines = content.lines
          first = "#{bullet} #{lines.first&.chomp}"
          rest  = lines.drop(1).map { |l| "   #{l}" }.join
          "#{first}\n#{rest}"
        end
        items.join
      end

      def apply_marks(text, marks)
        marks.reduce(text) do |acc, mark|
          case mark["type"]
          when "strong"      then "**#{acc}**"
          when "em"          then "*#{acc}*"
          when "code"        then "`#{acc}`"
          when "link"
            href = mark.dig("attrs", "href") || ""
            "[#{acc}](#{href})"
          when "strike"      then "~~#{acc}~~"
          when "underline", "textColor", "subsup"
            acc  # no Markdown equivalent; keep text
          else
            @unsupported_nodes << "mark:#{mark['type']}"
            acc
          end
        end
      end
    end
  end
end
