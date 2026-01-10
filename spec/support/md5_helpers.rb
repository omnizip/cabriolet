require "digest/md5"
require "tmpdir"
require "fileutils"

# MD5 comparison helper for libmspack parity tests
#
# Provides utilities to extract files to temp files and compute MD5 checksums
# for comparison with libmspack reference implementation
module MD5Helpers
  # Extract a file to a temp file and return its MD5 checksum
  #
  # @param extractor [Cabriolet::CAB::Extractor] The extractor instance
  # @param file [Cabriolet::Models::File] The file to extract
  # @return [String] The MD5 checksum as a 32-character hex string
  def extract_file_md5(extractor, file)
    Dir.mktmpdir do |tmpdir|
      # Extract to temp file
      output_path = File.join(tmpdir, "temp_file")
      extractor.extract_file(file, output_path)

      # Compute MD5 of the extracted content
      Digest::MD5.hexdigest(File.binread(output_path))
    end
  end

  # Extract multiple files and return their MD5 checksums
  #
  # @param extractor [Cabriolet::CAB::Extractor] The extractor instance
  # @param files [Array<Cabriolet::Models::File>] The files to extract
  # @return [Array<String>] Array of MD5 checksums
  def extract_files_md5(extractor, files)
    files.map { |file| extract_file_md5(extractor, file) }
  end

  # Verify that extracting files in different orders produces same MD5s
  #
  # @param cabinet_path [String] Path to cabinet file
  # @param expected_md5s [Array<String>] Expected MD5 checksums for each file
  # @return [Boolean] True if all extractions match expected MD5s
  def verify_any_order_extraction(cabinet_path, expected_md5s)
    io_system = Cabriolet::System::IOSystem.new
    decompressor = Cabriolet::CAB::Decompressor.new(io_system)
    extractor = Cabriolet::CAB::Extractor.new(io_system, decompressor)

    cabinet = decompressor.open(cabinet_path)
    files = cabinet.files

    # Verify we have the expected number of files
    return false unless files.length == expected_md5s.length

    # Extract each file and verify MD5
    files.each_with_index do |file, index|
      md5 = extract_file_md5(extractor, file)
      return false unless md5 == expected_md5s[index]
    end

    true
  end
end
