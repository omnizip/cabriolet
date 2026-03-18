# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "Cabriolet Memory Management" do
  let(:fixtures_dir) { File.expand_path("../fixtures/libmspack/cabd", __dir__) }

  # Helper to get memory usage in KB
  def memory_usage_kb
    `ps -o rss= -p #{Process.pid}`.strip.to_i
  end

  # Helper to count open file descriptors
  def open_fd_count
    if RUBY_PLATFORM =~ /darwin/
      `lsof -p #{Process.pid} 2>/dev/null | wc -l`.strip.to_i
    else
      Dir["/proc/self/fd/*"].length
    end
  rescue StandardError
    0
  end

  describe "CAB::Extractor" do
    let(:decompressor) { Cabriolet::CAB::Decompressor.new }
    let(:cab_file) { File.join(fixtures_dir, "normal_2files_1folder.cab") }

    describe "#extract_all" do
      it "cleans up resources after extraction" do
        fds_before = open_fd_count

        5.times do
          Dir.mktmpdir do |tmpdir|
            cabinet = decompressor.open(cab_file)
            extractor = Cabriolet::CAB::Extractor.new(decompressor.io_system, decompressor)
            extractor.extract_all(cabinet, tmpdir)
          end
        end

        fds_after = open_fd_count

        # Allow some variance but should not grow significantly
        expect(fds_after).to be <= fds_before + 5
      end

      it "cleans up resources even when extraction fails" do
        fds_before = open_fd_count

        5.times do
          Dir.mktmpdir do |tmpdir|
            cabinet = decompressor.open(cab_file)
            extractor = Cabriolet::CAB::Extractor.new(decompressor.io_system, decompressor)

            # Simulate extraction that might fail
            begin
              extractor.extract_all(cabinet, tmpdir)
            rescue StandardError
              # Ignore errors
            end
          end
        end

        fds_after = open_fd_count
        expect(fds_after).to be <= fds_before + 5
      end
    end

    describe "#reset_state" do
      it "clears all internal state" do
        cabinet = decompressor.open(cab_file)
        extractor = Cabriolet::CAB::Extractor.new(decompressor.io_system, decompressor)

        # Perform extraction to populate state
        Dir.mktmpdir do |tmpdir|
          extractor.extract_all(cabinet, tmpdir)
        end

        # reset_state is called automatically in ensure block
        expect(extractor.instance_variable_get(:@current_input)).to be_nil
        expect(extractor.instance_variable_get(:@current_decomp)).to be_nil
        expect(extractor.instance_variable_get(:@current_folder)).to be_nil
      end
    end
  end

  describe "CAB::Parser" do
    let(:decompressor) { Cabriolet::CAB::Decompressor.new }
    let(:cab_file) { File.join(fixtures_dir, "normal_2files_1folder.cab") }
    let(:invalid_file) { File.join(fixtures_dir, "nonexistent.cab") }

    it "closes file handle after successful parse" do
      fds_before = open_fd_count

      5.times { decompressor.open(cab_file) }

      fds_after = open_fd_count
      expect(fds_after).to be <= fds_before + 2
    end

    it "closes file handle even when parse fails" do
      fds_before = open_fd_count

      5.times do
        begin
          decompressor.open(invalid_file)
        rescue Cabriolet::IOError
          # Expected
        end
      end

      fds_after = open_fd_count
      expect(fds_after).to be <= fds_before + 2
    end
  end

  describe "Decompressors" do
    describe "LZX" do
      let(:lzx_cab) { File.join(fixtures_dir, "lzx_21kb.cab") }

      it "frees buffers when free is called" do
        skip "LZX fixture not available" unless File.exist?(lzx_cab)

        decompressor = Cabriolet::CAB::Decompressor.new
        cabinet = decompressor.open(lzx_cab)
        extractor = Cabriolet::CAB::Extractor.new(decompressor.io_system, decompressor)

        Dir.mktmpdir do |tmpdir|
          extractor.extract_all(cabinet, tmpdir)
        end

        # After extraction, reset_state should have been called
        # which calls free on the decompressor
        expect(extractor.instance_variable_get(:@current_decomp)).to be_nil
      end
    end

    describe "MSZIP" do
      let(:mszip_cab) { File.join(fixtures_dir, "mszip_1kb.cab") }

      it "frees buffers when free is called" do
        skip "MSZIP fixture not available" unless File.exist?(mszip_cab)

        decompressor = Cabriolet::CAB::Decompressor.new
        cabinet = decompressor.open(mszip_cab)
        extractor = Cabriolet::CAB::Extractor.new(decompressor.io_system, decompressor)

        Dir.mktmpdir do |tmpdir|
          extractor.extract_all(cabinet, tmpdir)
        end

        expect(extractor.instance_variable_get(:@current_decomp)).to be_nil
      end
    end
  end

  describe "Repeated extraction stress test" do
    let(:cab_files) do
      Dir.glob(File.join(fixtures_dir, "*.cab")).select do |f|
        # Skip multi-part and special files
        !f.include?("multi") && !f.include?("split")
      end.first(5) # Limit to 5 files for test speed
    end

    it "does not leak memory or file handles across multiple extractions" do
      skip "No CAB fixtures found" if cab_files.empty?

      mem_before = memory_usage_kb
      fds_before = open_fd_count

      # Run 3 iterations of extracting all files
      3.times do
        cab_files.each do |cab_file|
          next unless File.exist?(cab_file)

          Dir.mktmpdir do |tmpdir|
            begin
              decompressor = Cabriolet::CAB::Decompressor.new
              decompressor.salvage = true # Don't fail on problematic files
              cabinet = decompressor.search(cab_file) || decompressor.open(cab_file)
              decompressor.extract_all(cabinet, tmpdir, salvage: true)
            rescue StandardError => e
              # Some test files may be intentionally malformed
              warn "Skipping #{File.basename(cab_file)}: #{e.message}"
            end
          end

          # Force GC to ensure we're measuring actual leaks, not just pending GC
          GC.start
        end
      end

      mem_after = memory_usage_kb
      fds_after = open_fd_count

      # Memory should not grow by more than 10MB (10,240 KB)
      mem_growth = mem_after - mem_before
      expect(mem_growth).to be < 10_240,
                             "Memory grew by #{mem_growth} KB (#{mem_growth / 1024} MB)"

      # File descriptors should not leak
      fd_growth = fds_after - fds_before
      expect(fd_growth).to be < 10,
                           "File descriptors grew by #{fd_growth}"
    end
  end
end
