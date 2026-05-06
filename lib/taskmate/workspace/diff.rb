module Taskmate
  module Workspace
    class Diff
      CONTEXT_LINES = 3

      attr_reader :issue_key, :original_path, :modified_path, :hunks

      def self.compute(issue_file)
        synced_path = synced_copy_path(issue_file.path)
        original    = synced_path && File.exist?(synced_path) ? File.read(synced_path, encoding: "utf-8") : nil
        modified    = issue_file.raw_content

        new(
          issue_key:     issue_file.key,
          original:      original,
          modified:      modified,
          synced_path:   synced_path,
          issue_path:    issue_file.path
        )
      end

      def initialize(issue_key:, original:, modified:, synced_path: nil, issue_path: nil)
        @issue_key    = issue_key
        @original     = original
        @modified     = modified
        @synced_path  = synced_path
        @issue_path   = issue_path
        @hunks        = build_hunks
      end

      def empty?
        @original == @modified
      end

      def to_s
        return "(no changes)" if empty?

        header + @hunks.join("\n")
      end

      def self.synced_copy_path(issue_path)
        return nil if issue_path.nil?

        dir  = File.dirname(issue_path)
        base = File.basename(issue_path, ".md")
        File.join(dir, ".jira", "#{base}.synced.md")
      end

      private

      def header
        key_label  = @issue_key || "issue"
        orig_label = @original.nil? ? "/dev/null" : "a/issues/#{key_label}.md"
        new_label  = "b/issues/#{key_label}.md"
        "--- #{orig_label}\n+++ #{new_label}\n"
      end

      def build_hunks
        return [] if empty?

        orig_lines = (@original || "").each_line.map(&:chomp)
        mod_lines  = @modified.each_line.map(&:chomp)

        if @original.nil?
          return ["@@ -0,0 +1,#{mod_lines.size} @@"] + mod_lines.map { |l| "+#{l}" }
        end

        edits = compute_edits(orig_lines, mod_lines)
        group_into_hunks(edits, orig_lines.size, mod_lines.size)
      end

      # Returns array of [:eq/:del/:ins, orig_idx, mod_idx, line]
      def compute_edits(orig, mod)
        lcs  = compute_lcs(orig, mod)
        edits = []
        oi = mi = li = 0

        while oi < orig.size || mi < mod.size
          if li < lcs.size && oi < orig.size && orig[oi] == lcs[li] &&
             mi < mod.size && mod[mi] == lcs[li]
            edits << [:eq, oi, mi, orig[oi]]
            oi += 1; mi += 1; li += 1
          elsif mi < mod.size && (li >= lcs.size || mod[mi] != lcs[li])
            edits << [:ins, oi, mi, mod[mi]]
            mi += 1
          else
            edits << [:del, oi, mi, orig[oi]]
            oi += 1
          end
        end
        edits
      end

      def group_into_hunks(edits, orig_total, mod_total)
        changed_idxs = edits.each_index.select { |i| edits[i][0] != :eq }
        return [] if changed_idxs.empty?

        # Build contiguous ranges with context
        ranges = []
        changed_idxs.each do |ci|
          lo = [ci - CONTEXT_LINES, 0].max
          hi = [ci + CONTEXT_LINES, edits.size - 1].min
          if ranges.empty? || lo > ranges.last[1] + 1
            ranges << [lo, hi]
          else
            ranges.last[1] = [ranges.last[1], hi].max
          end
        end

        ranges.map do |lo, hi|
          hunk_edits = edits[lo..hi]
          orig_start = (hunk_edits.first[1] || 0) + 1
          mod_start  = (hunk_edits.first[2] || 0) + 1
          orig_count = hunk_edits.count { |e| %i[eq del].include?(e[0]) }
          mod_count  = hunk_edits.count { |e| %i[eq ins].include?(e[0]) }

          lines = ["@@ -#{orig_start},#{orig_count} +#{mod_start},#{mod_count} @@"]
          hunk_edits.each do |type, _, _, line|
            prefix = { eq: " ", del: "-", ins: "+" }[type]
            lines << "#{prefix}#{line}"
          end
          lines.join("\n")
        end
      end

      def compute_lcs(a, b)
        m, n = a.size, b.size
        dp = Array.new(m + 1) { Array.new(n + 1, 0) }
        (1..m).each { |i| (1..n).each { |j| dp[i][j] = a[i-1] == b[j-1] ? dp[i-1][j-1] + 1 : [dp[i-1][j], dp[i][j-1]].max } }
        result = []
        i, j = m, n
        while i > 0 && j > 0
          if a[i-1] == b[j-1] then result.unshift(a[i-1]); i -= 1; j -= 1
          elsif dp[i-1][j] > dp[i][j-1] then i -= 1
          else j -= 1
          end
        end
        result
      end
    end
  end
end
