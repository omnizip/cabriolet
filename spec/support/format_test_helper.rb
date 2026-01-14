# frozen_string_literal: true

# Format test helper methods
#
# Provides common test scenarios and helpers for testing all archive formats.
# Use these methods to create consistent, DRY tests across formats.

module FormatTestHelper
  # Test list command for a format
  #
  # @param format [Symbol] Format to test (:cab, :chm, etc.)
  # @param fixture [String] Path to fixture file
  def test_list_command(_format, fixture)
    cli = Cabriolet::CLI.new
    expect { cli.list(fixture) }.not_to raise_error
  end

  # Test extract command creates files
  #
  # @param format [Symbol] Format to test
  # @param fixture [String] Path to fixture file
  # @param expected_count [Integer] Expected number of extracted files
  def test_extract_command(_format, fixture, expected_count: nil)
    cli = Cabriolet::CLI.new
    Dir.mktmpdir do |output_dir|
      cli.extract(fixture, output_dir)

      extracted = Dir.glob("#{output_dir}/**/*").select { |f| File.file?(f) }
      expect(extracted.length).to be > 0

      if expected_count
        expect(extracted.length).to eq(expected_count)
      end
    end
  end

  # Test info command for a format
  #
  # @param format [Symbol] Format to test
  # @param fixture [String] Path to fixture file
  def test_info_command(_format, fixture)
    cli = Cabriolet::CLI.new
    expect { cli.info(fixture) }.not_to raise_error
  end

  # Test create command creates valid archive
  #
  # @param format [Symbol] Format to test
  # @param output [String] Output archive path
  # @param files [Array<String>] Input files to archive
  # @param options [Hash] Additional options for create
  def test_create_command(format, output, files, options = {})
    cli = Cabriolet::CLI.new
    cli.create(output, *files, **options)

    expect(File.exist?(output)).to be true

    # Verify created archive can be parsed back
    parser = parser_for_format(format)
    expect { parser.parse(output) }.not_to raise_error
  end

  # Test API parser with fixture
  #
  # @param format [Symbol] Format to test
  # @param fixture [String] Path to fixture file
  def test_api_parser(format, fixture)
    parser = parser_for_format(format)
    result = parser.parse(fixture)

    expect(result).not_to be_nil
    expect(result.file_count).to be_a(Integer)
    expect(result.file_count).to be >= 0
  end

  # Test API decompressor extracts content
  #
  # @param format [Symbol] Format to test
  # @param fixture [String] Path to fixture file
  def test_api_decompressor(format, fixture)
    parser = parser_for_format(format)
    parsed = parser.parse(fixture)

    decompressor = decompressor_for_format(format)
    decompressor.open(parsed)

    # Extract first file and verify content
    if parsed.files && !parsed.files.empty?
      first_file = parsed.files.first
      content = decompressor.extract_file(first_file)
      expect(content).not_to be_nil
      expect(content.length).to be > 0 if !first_file.empty?
    end

    decompressor.close
  end

  # Test API compressor creates valid archive
  #
  # @param format [Symbol] Format to test
  # @param output [String] Output archive path
  # @param files [Array<String>] Input files to compress
  # @param options [Hash] Additional options for compression
  def test_api_compressor(format, output, files, _options = {})
    compressor = compressor_for_format(format)

    files.each do |file|
      compressor.add_file(file)
    end

    compressor.write(output)

    # Verify created archive can be parsed
    parser = parser_for_format(format)
    expect { parser.parse(output) }.not_to raise_error
  end

  private

  # Get parser class for format
  #
  # @param format [Symbol] Format identifier
  # @return [Class] Parser class
  def parser_for_format(format)
    case format
    when :cab then Cabriolet::CAB::Parser
    when :chm then Cabriolet::CHM::Parser
    when :szdd then Cabriolet::SZDD::Parser
    when :kwaj then Cabriolet::KWAJ::Parser
    when :hlp then Cabriolet::HLP::Parser
    when :lit then Cabriolet::LIT::Parser
    # Note: OAB format has no parser class, only compressor/decompressor
    else
      raise ArgumentError, "Unknown format: #{format}"
    end.new
  end

  # Get decompressor class for format
  #
  # @param format [Symbol] Format identifier
  # @return [Object] Decompressor instance
  def decompressor_for_format(format)
    case format
    when :cab then Cabriolet::CAB::Decompressor.new
    when :chm then Cabriolet::CHM::Decompressor.new
    when :szdd then Cabriolet::SZDD::Decompressor.new
    when :kwaj then Cabriolet::KWAJ::Decompressor.new
    when :hlp then Cabriolet::HLP::Decompressor.new
    when :lit then Cabriolet::LIT::Decompressor.new
    when :oab then Cabriolet::OAB::Decompressor.new
    else
      raise ArgumentError, "Unknown format: #{format}"
    end
  end

  # Get compressor class for format
  #
  # @param format [Symbol] Format identifier
  # @return [Object] Compressor instance
  def compressor_for_format(format)
    case format
    when :cab then Cabriolet::CAB::Compressor.new
    when :chm then Cabriolet::CHM::Compressor.new
    when :szdd then Cabriolet::SZDD::Compressor.new
    when :kwaj then Cabriolet::KWAJ::Compressor.new
    when :hlp then Cabriolet::HLP::Compressor.new
    when :lit then Cabriolet::LIT::Compressor.new
    when :oab then Cabriolet::OAB::Compressor.new
    else
      raise ArgumentError, "Unknown format: #{format}"
    end
  end
end
