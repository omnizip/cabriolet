# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require_relative "../support/fixtures"

RSpec.describe Cabriolet::CHM::Compressor do
  let(:compressor) { described_class.new }
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  def create_temp_file(name, content)
    path = File.join(temp_dir, name)
    File.write(path, content)
    path
  end

  def create_chm_file(files_hash)
    chm_path = File.join(temp_dir, "test.chm")
    compressor = described_class.new

    files_hash.each do |chm_path_name, content|
      source = create_temp_file(File.basename(chm_path_name), content)
      compressor.add_file(source, chm_path_name, section: :compressed)
    end

    compressor.generate(chm_path)
    chm_path
  end

  describe "#initialize" do
    it "creates a new compressor instance" do
      expect(compressor).to be_a(described_class)
    end

    it "initializes with empty files list" do
      expect(compressor.files).to be_empty
    end

    it "accepts custom io_system" do
      io_system = Cabriolet::System::IOSystem.new
      compressor = described_class.new(io_system)
      expect(compressor.io_system).to eq(io_system)
    end
  end

  describe "#add_file" do
    let(:source_file) do
      create_temp_file("test.html", "<html><body>Test</body></html>")
    end

    it "adds a file to the compressor" do
      compressor.add_file(source_file, "/test.html")
      expect(compressor.files.size).to eq(1)
    end

    it "requires chm_path to start with /" do
      expect do
        compressor.add_file(source_file, "test.html")
      end.to raise_error(ArgumentError, /must start with/)
    end

    it "raises error if source file does not exist" do
      expect do
        compressor.add_file("/nonexistent/file.html", "/test.html")
      end.to raise_error(ArgumentError, /not found/)
    end

    it "allows specifying section" do
      compressor.add_file(source_file, "/test.html", section: :uncompressed)
      expect(compressor.files.first[:section]).to eq(:uncompressed)
    end

    it "defaults to compressed section" do
      compressor.add_file(source_file, "/test.html")
      expect(compressor.files.first[:section]).to eq(:compressed)
    end
  end

  describe "#generate" do
    let(:source_file) do
      create_temp_file("index.html", "<html><body>Hello World</body></html>")
    end
    let(:output_file) { File.join(temp_dir, "output.chm") }

    it "generates a CHM file" do
      compressor.add_file(source_file, "/index.html")
      bytes = compressor.generate(output_file)

      expect(File.exist?(output_file)).to be true
      expect(bytes).to be > 0
    end

    it "raises error if no files added" do
      expect do
        compressor.generate(output_file)
      end.to raise_error(ArgumentError, /No files/)
    end

    it "accepts custom window_bits option" do
      compressor.add_file(source_file, "/index.html")
      bytes = compressor.generate(output_file, window_bits: 15)

      expect(File.exist?(output_file)).to be true
      expect(bytes).to be > 0
    end

    it "validates window_bits range" do
      compressor.add_file(source_file, "/index.html")

      expect do
        compressor.generate(output_file, window_bits: 14)
      end.to raise_error(ArgumentError, /window_bits must be 15-21/)
    end

    it "accepts custom timestamp" do
      compressor.add_file(source_file, "/index.html")
      timestamp = Time.now.to_i - 86_400 # Yesterday
      bytes = compressor.generate(output_file, timestamp: timestamp)

      expect(bytes).to be > 0
    end

    it "accepts custom language_id" do
      compressor.add_file(source_file, "/index.html")
      bytes = compressor.generate(output_file, language_id: 0x0804) # Chinese

      expect(bytes).to be > 0
    end

    it "cleans up on error" do
      compressor.add_file(source_file, "/index.html")

      # Force an error by using invalid io_system
      allow(compressor.io_system).to receive(:open).and_raise(StandardError,
                                                              "Test error")

      expect do
        compressor.generate(output_file)
      end.to raise_error(StandardError, "Test error")

      expect(File.exist?(output_file)).to be false
    end
  end

  describe "CHM file generation" do
    it "creates valid ITSF signature" do
      source = create_temp_file("test.html", "<html><body>Test</body></html>")
      compressor.add_file(source, "/test.html")
      output = File.join(temp_dir, "test.chm")

      compressor.generate(output)

      File.open(output, "rb") do |f|
        signature = f.read(4)
        expect(signature).to eq("ITSF")
      end
    end

    it "handles multiple files" do
      files = {
        "/index.html" => "<html><body>Index</body></html>",
        "/page1.html" => "<html><body>Page 1</body></html>",
        "/page2.html" => "<html><body>Page 2</body></html>",
      }

      files.each do |chm_path, content|
        source = create_temp_file(File.basename(chm_path), content)
        compressor.add_file(source, chm_path)
      end

      output = File.join(temp_dir, "multi.chm")
      bytes = compressor.generate(output)

      expect(File.exist?(output)).to be true
      expect(bytes).to be > 0
    end

    it "handles mixed sections (compressed and uncompressed)" do
      html_file = create_temp_file("index.html",
                                   "<html><body>Test</body></html>")
      image_file = create_temp_file("image.png", "\x89PNG\r\n\x1a\n")

      compressor.add_file(html_file, "/index.html", section: :compressed)
      compressor.add_file(image_file, "/image.png", section: :uncompressed)

      output = File.join(temp_dir, "mixed.chm")
      bytes = compressor.generate(output)

      expect(File.exist?(output)).to be true
      expect(bytes).to be > 0
    end

    it "sorts files by name in directory" do
      files = ["/zebra.html", "/apple.html", "/middle.html"]
      files.each do |chm_path|
        source = create_temp_file(File.basename(chm_path),
                                  "<html>Content</html>")
        compressor.add_file(source, chm_path)
      end

      output = File.join(temp_dir, "sorted.chm")
      compressor.generate(output)

      expect(File.exist?(output)).to be true
    end
  end

  describe "round-trip (create → extract)" do
    it "round-trips empty files correctly" do
      # Create empty file
      source = create_temp_file("empty.html", "")

      compressor.add_file(source, "/empty.html")
      chm_file = File.join(temp_dir, "empty.chm")
      compressor.generate(chm_file)

      # Extract
      decompressor = Cabriolet::CHM::Decompressor.new
      chm = decompressor.open(chm_file)

      file = chm.find_file("/empty.html")
      expect(file).not_to be_nil
      expect(file.length).to eq(0)

      extract_path = File.join(temp_dir, "extracted_empty.html")
      decompressor.extract(file, extract_path)

      expect(File.exist?(extract_path)).to be true
      expect(File.size(extract_path)).to eq(0)

      decompressor.close
    end
  end

  describe "system files generation" do
    it "generates ControlData file" do
      source = create_temp_file("test.html", "<html><body>Test</body></html>")
      compressor.add_file(source, "/test.html", section: :compressed)
      chm_file = File.join(temp_dir, "test.chm")
      compressor.generate(chm_file)

      decompressor = Cabriolet::CHM::Decompressor.new
      chm = decompressor.open(chm_file)

      control_file = chm.all_sysfiles.find { |f| f.filename == Cabriolet::CHM::Compressor::CONTROL_NAME }
      expect(control_file).not_to be_nil
      expect(control_file.length).to eq(28)

      decompressor.close
    end

    it "generates ResetTable file" do
      source = create_temp_file("test.html", "<html><body>Test</body></html>")
      compressor.add_file(source, "/test.html", section: :compressed)
      chm_file = File.join(temp_dir, "test.chm")
      compressor.generate(chm_file)

      decompressor = Cabriolet::CHM::Decompressor.new
      chm = decompressor.open(chm_file)

      rtable_file = chm.all_sysfiles.find { |f| f.filename == Cabriolet::CHM::Compressor::RTABLE_NAME }
      expect(rtable_file).not_to be_nil
      expect(rtable_file.length).to be > 0

      decompressor.close
    end

    it "generates SpanInfo file" do
      source = create_temp_file("test.html", "<html><body>Test</body></html>")
      compressor.add_file(source, "/test.html", section: :compressed)
      chm_file = File.join(temp_dir, "test.chm")
      compressor.generate(chm_file)

      decompressor = Cabriolet::CHM::Decompressor.new
      chm = decompressor.open(chm_file)

      spaninfo_file = chm.all_sysfiles.find { |f| f.filename == Cabriolet::CHM::Compressor::SPANINFO_NAME }
      expect(spaninfo_file).not_to be_nil
      expect(spaninfo_file.length).to eq(8)

      decompressor.close
    end

    it "generates Content file" do
      source = create_temp_file("test.html", "<html><body>Test</body></html>")
      compressor.add_file(source, "/test.html", section: :compressed)
      chm_file = File.join(temp_dir, "test.chm")
      compressor.generate(chm_file)

      decompressor = Cabriolet::CHM::Decompressor.new
      chm = decompressor.open(chm_file)

      content_file = chm.all_sysfiles.find { |f| f.filename == Cabriolet::CHM::Compressor::CONTENT_NAME }
      expect(content_file).not_to be_nil
      expect(content_file.length).to be > 0

      decompressor.close
    end
  end

  describe "ENCINT encoding" do
    it "encodes zero correctly" do
      result = Cabriolet::Binary::ENCINTWriter.encode(0)
      expect(result).to eq("\x00".b)
    end

    it "encodes small values correctly" do
      result = Cabriolet::Binary::ENCINTWriter.encode(127)
      expect(result).to eq("\x7F".b)
    end

    it "encodes multi-byte values correctly" do
      result = Cabriolet::Binary::ENCINTWriter.encode(128)
      expect(result.bytes.first & 0x80).to eq(0x80)
    end

    it "raises error for negative values" do
      expect do
        Cabriolet::Binary::ENCINTWriter.encode(-1)
      end.to raise_error(ArgumentError, /non-negative/)
    end

    it "round-trips values correctly" do
      [0, 1, 127, 128, 255, 256, 1000, 10_000, 100_000].each do |value|
        encoded = Cabriolet::Binary::ENCINTWriter.encode(value)
        decoded, = Cabriolet::Binary::ENCINTReader.read_from_string(encoded, 0)
        expect(decoded).to eq(value)
      end
    end
  end

  describe "fixture compatibility" do
    let(:decompressor) { Cabriolet::CHM::Decompressor.new }

    context "can open and parse fixture files" do
      it "opens all basic CHM fixtures" do
        basic_fixtures = Fixtures.for(:chm).scenario(:basic)

        basic_fixtures.each do |fixture_path|
          chm = decompressor.open(fixture_path)
          expect(chm).to be_a(Cabriolet::Models::CHMHeader)
          expect(chm.chunk_size).to be > 0
          decompressor.close
        end
      end
    end

    context "can handle edge case fixtures" do
      it "opens CVE test files" do
        cve_fixtures = Fixtures.for(:chm).scenario(:cve).take(3)

        cve_fixtures.each do |fixture_path|
          chm = decompressor.open(fixture_path)
          expect(chm).to be_a(Cabriolet::Models::CHMHeader)
          decompressor.close
        end
      end
    end
  end
end
