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
        when "doc", "listItem" then render_children(node, separator: "\n")
        when "paragraph"       then render_paragraph(node)
        when "heading"         then render_heading(node)
        when "bulletList"      then render_list(node, ordered: false)
        when "orderedList"     then render_list(node, ordered: true)
        when "codeBlock"       then render_code_block(node)
        when "hardBreak"       then "\n"
        when "text"            then apply_marks(node["text"].to_s, Array(node["marks"]))
        when "blockquote"      then render_blockquote(node)
        when "rule"            then "---\n"
        else                        record_unsupported(node)
        end
      end

      def render_paragraph(node)
        content = render_children(node)
        content.empty? ? "" : "#{content}\n"
      end

      def render_heading(node)
        level  = node.dig("attrs", "level") || 1
        prefix = "#" * [level, 6].min
        "#{prefix} #{render_children(node)}\n"
      end

      def render_code_block(node)
        lang = node.dig("attrs", "language") || ""
        code = render_children(node)
        code = "#{code}\n" unless code.end_with?("\n")
        "```#{lang}\n#{code}```\n"
      end

      def render_blockquote(node)
        render_children(node, separator: "\n").each_line.map { |l| "> #{l}" }.join
      end

      def record_unsupported(node)
        type = node["type"] || "unknown"
        @unsupported_nodes << type
        "<!-- taskmate: unsupported_adf_node type=\"#{type}\" -->\n"
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
          when "strike" then "~~#{acc}~~"
          when "underline", "textColor", "subsup"
            acc # no Markdown equivalent; keep text
          else
            @unsupported_nodes << "mark:#{mark['type']}"
            acc
          end
        end
      end
    end
  end
end
