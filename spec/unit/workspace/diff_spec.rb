require "spec_helper"
require "taskmate/workspace/diff"
require "taskmate/workspace/issue_file"

RSpec.describe Taskmate::Workspace::Diff do
  def build_diff(original:, modified:, key: "SAR-1")
    described_class.new(issue_key: key, original: original, modified: modified)
  end

  describe "#empty?" do
    it "is true when original and modified are identical" do
      d = build_diff(original: "same\n", modified: "same\n")
      expect(d.empty?).to be(true)
    end

    it "is false when content differs" do
      d = build_diff(original: "old\n", modified: "new\n")
      expect(d.empty?).to be(false)
    end

    it "is false when original is nil (new file)" do
      d = build_diff(original: nil, modified: "content\n")
      expect(d.empty?).to be(false)
    end
  end

  describe "#to_s" do
    it "returns '(no changes)' when empty" do
      d = build_diff(original: "same\n", modified: "same\n")
      expect(d.to_s).to eq("(no changes)")
    end

    it "includes --- and +++ headers" do
      d = build_diff(original: "old\n", modified: "new\n")
      output = d.to_s
      expect(output).to include("--- a/issues/SAR-1.md")
      expect(output).to include("+++ b/issues/SAR-1.md")
    end

    it "uses /dev/null as original header for new files" do
      d = build_diff(original: nil, modified: "line1\nline2\n")
      expect(d.to_s).to include("--- /dev/null")
    end

    it "marks deleted lines with -" do
      d = build_diff(original: "removed\nkept\n", modified: "kept\n")
      expect(d.to_s).to include("-removed")
    end

    it "marks added lines with +" do
      d = build_diff(original: "kept\n", modified: "kept\nadded\n")
      expect(d.to_s).to include("+added")
    end

    it "marks unchanged lines with a space" do
      d = build_diff(original: "context\nchanged\n", modified: "context\nnew\n")
      expect(d.to_s).to include(" context")
    end

    it "produces a valid @@ hunk header" do
      d = build_diff(original: "a\n", modified: "b\n")
      expect(d.to_s).to match(/@@ -\d+,\d+ \+\d+,\d+ @@/)
    end

    it "new file hunk header uses @@ -0,0 +1,N @@ format" do
      d = build_diff(original: nil, modified: "line1\nline2\n")
      expect(d.to_s).to include("@@ -0,0 +1,2 @@")
    end
  end

  describe "#hunks" do
    it "returns empty array when no changes" do
      d = build_diff(original: "same\n", modified: "same\n")
      expect(d.hunks).to be_empty
    end

    it "returns hunks array when there are changes" do
      d = build_diff(original: "a\nb\nc\n", modified: "a\nX\nc\n")
      expect(d.hunks).not_to be_empty
    end

    it "merges nearby changes into one hunk when within CONTEXT_LINES" do
      # Changes at line 3 and line 7 in a 10-line file — only 4 apart,
      # well within CONTEXT_LINES=3 reach of each other
      original = "#{(1..10).map { |i| "line#{i}" }.join("\n")}\n"
      modified = original.sub("line3", "CHANGED3").sub("line7", "CHANGED7")
      d = build_diff(original: original, modified: modified)
      expect(d.hunks.size).to eq(1)
    end

    it "produces separate hunks for far-apart changes" do
      original = "#{(1..20).map { |i| "line#{i}" }.join("\n")}\n"
      modified = original.sub("line1", "X").sub("line15", "Y")
      d = build_diff(original: original, modified: modified)
      expect(d.hunks.size).to eq(2)
    end
  end

  describe ".compute" do
    it "returns Diff with no synced copy treated as nil original" do
      dir = Dir.mktmpdir
      begin
        issue_path = File.join(dir, "SAR-1.md")
        File.write(issue_path, "---\nkey: SAR-1\nsummary: Test\nissue_type: Task\n---\nBody\n")
        issue = Taskmate::Workspace::IssueFile.read(issue_path)
        diff = described_class.compute(issue)
        expect(diff.empty?).to be(false)
        expect(diff.to_s).to include("--- /dev/null")
      ensure
        FileUtils.rm_rf(dir)
      end
    end

    it "returns empty diff when synced copy matches current content" do
      dir = Dir.mktmpdir
      begin
        jira_dir = File.join(dir, ".jira")
        FileUtils.mkdir_p(jira_dir)
        content = "---\nkey: SAR-1\nsummary: Test\nissue_type: Task\n---\nBody\n"
        issue_path = File.join(dir, "SAR-1.md")
        File.write(issue_path, content)
        File.write(File.join(jira_dir, "SAR-1.synced.md"), content)
        issue = Taskmate::Workspace::IssueFile.read(issue_path)
        diff = described_class.compute(issue)
        expect(diff.empty?).to be(true)
      ensure
        FileUtils.rm_rf(dir)
      end
    end
  end
end
