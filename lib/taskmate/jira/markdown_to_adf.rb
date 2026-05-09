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
        blocks = []
        idx    = 0
        while idx < lines.size
          block, idx = parse_one_block(lines, idx)
          blocks << block if block
        end
        blocks
      end

      def parse_one_block(lines, idx)
        line = lines[idx]
        return parse_code_fence(lines, idx) if line.start_with?("```")
        if (m = line.match(/^(\#{1,6})\s+(.+)/))
          return [Block.new(type: :heading, data: { level: m[1].length, text: m[2] }), idx + 1]
        end
        return [Block.new(type: :rule, data: {}), idx + 1] if line.match?(/^---+$|^\*\*\*+$/)
        if line.match?(/^[-*+]\s+/)
          items, new_idx = collect_list(lines, idx, :bullet)
          return [Block.new(type: :bullet_list, data: { items: items }), new_idx]
        end
        if line.match?(/^\d+\.\s+/)
          items, new_idx = collect_list(lines, idx, :ordered)
          return [Block.new(type: :ordered_list, data: { items: items }), new_idx]
        end
        return [nil, idx + 1] if line.strip.empty?
        parse_paragraph_block(lines, idx)
      end

      def parse_code_fence(lines, idx)
        lang = lines[idx].sub(/^```/, "").strip
        code_lines = []
        idx += 1
        while idx < lines.size && !lines[idx].start_with?("```")
          code_lines << lines[idx]
          idx += 1
        end
        [Block.new(type: :code_block, data: { lang: lang, code: code_lines.join("\n") }), idx + 1]
      end

      def parse_paragraph_block(lines, idx)
        para_lines = [lines[idx]]
        idx += 1
        while idx < lines.size && !lines[idx].strip.empty? && !block_marker?(lines[idx])
          para_lines << lines[idx]
          idx += 1
        end
        [Block.new(type: :paragraph, data: { text: para_lines.join(" ") }), idx]
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
        when :heading    then render_heading_block(block)
        when :paragraph  then { "type" => "paragraph", "content" => inline_nodes(block.data[:text]) }
        when :bullet_list  then { "type" => "bulletList",  "content" => block.data[:items].map { |t| list_item_node(t) } }
        when :ordered_list then { "type" => "orderedList", "content" => block.data[:items].map { |t| list_item_node(t) } }
        when :code_block then render_code_fence_block(block)
        when :rule       then { "type" => "rule" }
        end
      end

      def render_heading_block(block)
        { "type" => "heading", "attrs" => { "level" => block.data[:level] }, "content" => inline_nodes(block.data[:text]) }
      end

      def render_code_fence_block(block)
        { "type" => "codeBlock", "attrs" => { "language" => block.data[:lang] },
          "content" => [{ "type" => "text", "text" => block.data[:code] }] }
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
          node, advance = match_inline(text, pos)
          nodes << node
          pos += advance
        end
        nodes.empty? ? [{ "type" => "text", "text" => "" }] : nodes
      end

      def match_inline(text, pos) # rubocop:disable Metrics/MethodLength
        slice = text[pos..]
        if (m = slice.match(/\A\*\*(.+?)\*\*/))
          [text_node(m[1], [mark("strong")]), m[0].length]
        elsif (m = slice.match(/\A\*(.+?)\*/))
          [text_node(m[1], [mark("em")]), m[0].length]
        elsif (m = slice.match(/\A`([^`]+)`/))
          [text_node(m[1], [mark("code")]), m[0].length]
        elsif (m = slice.match(/\A\[([^\]]+)\]\(([^)]+)\)/))
          [text_node(m[1], [link_mark(m[2])]), m[0].length]
        else
          plain_end = pos + 1
          plain_end += 1 while plain_end < text.length && !text[plain_end..].match?(/\A(\*\*|\*|`|\[)/)
          [text_node(text[pos...plain_end], []), plain_end - pos]
        end
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
