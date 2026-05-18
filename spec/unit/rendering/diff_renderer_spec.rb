require "spec_helper"
require "taskmate/rendering/diff_renderer"

RSpec.describe Taskmate::Rendering::DiffRenderer do
  let(:null_pastel) do
    double("pastel").tap do |p|
      allow(p).to receive(:green) { |s| s }
      allow(p).to receive(:red)   { |s| s }
    end
  end

  describe ".render" do
    it "returns empty string for nil input" do
      expect(described_class.render(nil, pastel: null_pastel)).to eq("")
    end

    it "returns empty string for empty input" do
      expect(described_class.render("", pastel: null_pastel)).to eq("")
    end

    it "colorizes added lines with green" do
      pastel = double("pastel")
      allow(pastel).to receive(:green).with("+added line").and_return("GREEN:+added line")
      result = described_class.render("+added line\n", pastel: pastel)
      expect(result).to eq("GREEN:+added line\n")
    end

    it "colorizes removed lines with red" do
      pastel = double("pastel")
      allow(pastel).to receive(:red).with("-removed line").and_return("RED:-removed line")
      result = described_class.render("-removed line\n", pastel: pastel)
      expect(result).to eq("RED:-removed line\n")
    end

    it "does not colorize +++ header lines" do
      result = described_class.render("+++ b/file.md\n", pastel: null_pastel)
      expect(result).to eq("+++ b/file.md\n")
      expect(null_pastel).not_to have_received(:green)
    end

    it "does not colorize --- header lines" do
      result = described_class.render("--- a/file.md\n", pastel: null_pastel)
      expect(result).to eq("--- a/file.md\n")
      expect(null_pastel).not_to have_received(:red)
    end

    it "leaves context lines unchanged" do
      result = described_class.render(" context line\n", pastel: null_pastel)
      expect(result).to eq(" context line\n")
      expect(null_pastel).not_to have_received(:green)
      expect(null_pastel).not_to have_received(:red)
    end

    context "with a full unified diff" do
      let(:diff) do
        <<~DIFF
          --- a/FOO-1.md
          +++ b/FOO-1.md
          @@ -1,3 +1,3 @@
           unchanged
          -old line
          +new line
        DIFF
      end

      let(:pastel) do
        double("pastel").tap do |p|
          allow(p).to receive(:green) { |s| "[G]#{s}" }
          allow(p).to receive(:red)   { |s| "[R]#{s}" }
        end
      end

      let(:lines) { described_class.render(diff, pastel: pastel).lines }

      it "passes through header and context lines unchanged" do
        expect(lines[0]).to eq("--- a/FOO-1.md\n")
        expect(lines[1]).to eq("+++ b/FOO-1.md\n")
        expect(lines[2]).to eq("@@ -1,3 +1,3 @@\n")
        expect(lines[3]).to eq(" unchanged\n")
      end

      it "colorizes removed and added lines" do
        expect(lines[4]).to eq("[R]-old line\n")
        expect(lines[5]).to eq("[G]+new line\n")
      end
    end

    it "preserves trailing newline on colorized lines" do
      pastel = double("pastel")
      allow(pastel).to receive(:green) { |s| s }
      result = described_class.render("+line\n", pastel: pastel)
      expect(result).to end_with("\n")
    end
  end
end
