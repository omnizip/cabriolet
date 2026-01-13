# frozen_string_literal: true

# Shared RSpec examples for edge case testing
#
# Provides common edge case test scenarios that can be included
# in format-specific test suites using `it_behaves_like`.

require_relative "fixtures"

# Shared examples for edge case handling across all formats
#
# @param format [Symbol] Format identifier (:cab, :chm, :szdd, :kwaj, :hlp, :lit, :oab)
RSpec.shared_examples "edge case handling" do |format|
  let(:fixtures) { Fixtures.for(format) }

  context "with non-existent file" do
    it "API raises IOError" do
      parser = parser_for_format(format)
      expect { parser.parse("/nonexistent.#{format}") }
        .to raise_error(Cabriolet::IOError)
    end

    it "CLI exits with error" do
      cli = Cabriolet::CLI.new
      expect { cli.list("/nonexistent.#{format}") }
        .to raise_error(SystemExit)
    end
  end

  context "with empty file" do
    it "API raises ParseError" do
      # Create empty temp file
      empty_file = create_empty_file(format)

      parser = parser_for_format(format)
      expect { parser.parse(empty_file) }
        .to raise_error(Cabriolet::ParseError, /empty|invalid|signature/i)
    end
  end

  context "with wrong format signature" do
    it "API raises SignatureError" do
      # Create file with wrong signature
      wrong_format = create_wrong_format_file(format)

      parser = parser_for_format(format)
      expect { parser.parse(wrong_format) }
        .to raise_error(Cabriolet::SignatureError)
    end
  end

  # Test corrupted fixtures if available
  if fixtures.respond_to?(:edge_case) && !fixtures.edge_case(:corrupted).nil?
    context "with corrupted file" do
      let(:corrupted_fixture) { fixtures.edge_case(:corrupted) }

      it "API handles corruption gracefully" do
        parser = parser_for_format(format)

        # Should either raise specific error or handle salvage mode
        expect { parser.parse(corrupted_fixture) }
          .to either raise_error(Cabriolet::ParseError)
          .or raise_error(Cabriolet::CorruptionError)
          .or be_a(Cabriolet::Models::Cabinet) # Salvageable
      end
    end
  end
end

# Helper methods for edge case testing

module EdgeCaseHelpers
  # Create an empty temporary file for testing
  #
  # @param format [Symbol] Format identifier
  # @return [String] Path to empty file
  def create_empty_file(format)
    ext = extension_for_format(format)
    Dir.mktmpdir do |dir|
      empty_file = File.join(dir, "empty#{ext}")
      File.write(empty_file, "")
      return empty_file
    end
  end

  # Create a file with wrong format signature
  #
  # @param format [Symbol] Format identifier
  # @return [String] Path to file with wrong signature
  def create_wrong_format_file(format)
    ext = extension_for_format(format)
    Dir.mktmpdir do |dir|
      wrong_file = File.join(dir, "wrong#{ext}")
      File.write(wrong_file, "WRONG_SIGNATURE")
      return wrong_file
    end
  end

  # Get file extension for format
  #
  # @param format [Symbol] Format identifier
  # @return [String] File extension (with dot)
  def extension_for_format(format)
    case format
    when :cab then ".cab"
    when :chm then ".chm"
    when :szdd then "._"
    when :kwaj then ".kwj"
    when :hlp then ".hlp"
    when :lit then ".lit"
    when :oab then ".oab"
    else
      raise ArgumentError, "Unknown format: #{format}"
    end
  end

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
    when :oab then Cabriolet::OAB::Parser
    else
      raise ArgumentError, "Unknown format: #{format}"
    end
  end
end
