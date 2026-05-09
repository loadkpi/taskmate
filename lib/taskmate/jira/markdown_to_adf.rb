module Taskmate
  module Jira
    class MarkdownToAdf
      ADF_VERSION = 1

      def convert(markdown)
        lines   = markdown.to_s.lines.map(&:chomp)
        blocks  = parse_blocks(lines)
        content = blocks.map { |b| render_block(b) }.compact

        { "type" => "doc", "version" => ADF_VERSION, "content" => content }
      end

      # ---------- Block parsing ----------

      Block = Struct.new(:type, :data, keyword_init: true)

      private

      def parse_blocks(lines)
        blocks  = []
        i       = 0

        while i < lines.size
          line = lines[i]

          # Fenced code block
          if line.start_with?("```")
            lang = line.sub(/^```/, "").strip
            code_lines = []
            i += 1
            while i < lines.size && !lines[i].start_with?("```")
              code_lines << lines[i]
              i += 1
            end
            blocks << Block.new(type: :code_block, data: { lang: lang, code: code_lines.join("\n") })
            i += 1
            next
          end

          # Heading
          if (m = line.match(/^(\#{1,6})\s+(.+)/))
            blocks << Block.new(type: :heading, data: { level: m[1].length, text: m[2] })
            i += 1
            next
          end

          # Horizontal rule
          if line.match?(/^---+$|^\*\*\*+$/)
            blocks << Block.new(type: :rule, data: {})
            i += 1
            next
          end

          # Bullet list
          if line.match?(/^[-*+]\s+/)
            items, i = collect_list(lines, i, :bullet)
            blocks << Block.new(type: :bullet_list, data: { items: items })
            next
          end

          # Ordered list
          if line.match?(/^\d+\.\s+/)
            items, i = collect_list(lines, i, :ordered)
            blocks << Block.new(type: :ordered_list, data: { items: items })
            next
          end

          # Blank line — skip
          if line.strip.empty?
            i += 1
            next
          end

          # Paragraph — collect until blank or next block marker
          para_lines = [line]
          i += 1
          while i < lines.size && !lines[i].strip.empty? && !block_marker?(lines[i])
            para_lines << lines[i]
            i += 1
          end
          blocks << Block.new(type: :paragraph, data: { text: para_lines.join(" ") })
        end

        blocks
      end

      def block_marker?(line)
        line.match?(/^\#{1,6}\s|^```|^[-*+]\s|^\d+\.\s|^---+$/)
      end

      def collect_list(lines, idx, _kind)
        items = []
        while idx < lines.size && lines[idx].match?(/^([-*+]|\d+\.)\s+/)
          text = lines[idx].sub(/^([-*+]|\d+\.)\s+/, "")
          items << text
          idx += 1
        end
        [items, idx]
      end

      # ---------- ADF rendering ----------

      def render_block(block)
        case block.type
        when :heading
          {
            "type" => "heading",
            "attrs" => { "level" => block.data[:level] },
            "content" => inline_nodes(block.data[:text])
          }
        when :paragraph
          {
            "type" => "paragraph",
            "content" => inline_nodes(block.data[:text])
          }
        when :bullet_list
          {
            "type" => "bulletList",
            "content" => block.data[:items].map { |t| list_item_node(t) }
          }
        when :ordered_list
          {
            "type" => "orderedList",
            "content" => block.data[:items].map { |t| list_item_node(t) }
          }
        when :code_block
          {
            "type" => "codeBlock",
            "attrs" => { "language" => block.data[:lang] },
            "content" => [{ "type" => "text", "text" => block.data[:code] }]
          }
        when :rule
          { "type" => "rule" }
        end
      end

      def list_item_node(text)
        {
          "type" => "listItem",
          "content" => [{
            "type" => "paragraph",
            "content" => inline_nodes(text)
          }]
        }
      end

      # ---------- Inline parsing ----------

      def inline_nodes(text)
        nodes = []
        pos   = 0

        while pos < text.length
          # Bold
          if (m = text[pos..].match(/\A\*\*(.+?)\*\*/))
            nodes << text_node(m[1], [mark("strong")])
            pos += m[0].length
          # Italic
          elsif (m = text[pos..].match(/\A\*(.+?)\*/))
            nodes << text_node(m[1], [mark("em")])
            pos += m[0].length
          # Inline code
          elsif (m = text[pos..].match(/\A`([^`]+)`/))
            nodes << text_node(m[1], [mark("code")])
            pos += m[0].length
          # Link
          elsif (m = text[pos..].match(/\A\[([^\]]+)\]\(([^)]+)\)/))
            nodes << text_node(m[1], [link_mark(m[2])])
            pos += m[0].length
          # Plain character(s)
          else
            # Collect plain chars until next special sequence
            plain_end = pos + 1
            plain_end += 1 while plain_end < text.length && !text[plain_end..].match?(/\A(\*\*|\*|`|\[)/)
            nodes << text_node(text[pos...plain_end], [])
            pos = plain_end
          end
        end

        nodes.empty? ? [{ "type" => "text", "text" => "" }] : nodes
      end

      def text_node(content, marks)
        node = { "type" => "text", "text" => content }
        node["marks"] = marks unless marks.empty?
        node
      end

      def mark(type)
        { "type" => type }
      end

      def link_mark(href)
        { "type" => "link", "attrs" => { "href" => href } }
      end
    end
  end
end
