# frozen_string_literal: true

require "spec_helper"
require_relative "../support/fixtures"
require_relative "../support/stdout_capture"

# Characterization specs for the format command handlers.
#
# For every handler's #list, #info and #test these pin the exact stdout, plus
# the class and message of whatever the failing paths raise. The single
# exception is CAB's #info, whose modification times render in the local zone
# and are normalized before comparison.
#
# Return values are asserted in exactly one example: CAB's #list and #info,
# which used to leak a file array and now return nil like every other handler.
# Nothing else asserts a return value.
#
# The three methods share a validate -> open -> render -> close skeleton that
# lives in BaseCommandHandler, so a change to the template must not change what
# any format prints. The abstract hooks that skeleton calls are covered in
# base_command_handler_spec.rb.
RSpec.describe Cabriolet::Commands::BaseCommandHandler do
  include StdoutCapture

  # The three read-only commands the base class implements as a template.
  def read_commands
    %i[list info test]
  end

  def capture(handler, command, file, options = {})
    capture_stdout { handler.public_send(command, file, options) }
  end

  def capture_failure(handler, command, file)
    capture_stdout_failure { handler.public_send(command, file, {}) }
  end

  describe "CAB" do
    let(:file) { Fixtures.for(:cab).path(:basic) }
    let(:handler) { Cabriolet::CAB::CommandHandler.new(verbose: false) }

    it "prints the cabinet listing" do
      output, = capture(handler, :list, file)

      expect(output).to eq(<<~OUT)
        Cabinet: #{file}
        Set ID: 1570, Index: 0
        Folders: 1, Files: 2

        Files:
          hello.c (77 bytes)
          welcome.c (74 bytes)
      OUT
    end

    it "prints detailed cabinet information" do
      output, = capture(handler, :info, file)
      # Modification times render in the local zone; the rest is pinned exactly.
      normalized = output.gsub(/^    Modified: .+$/, "    Modified: <TIME>")

      expect(normalized).to eq(<<~OUT)
        Cabinet Information
        ==================================================
        Filename: #{file}
        Set ID: 1570
        Set Index: 0
        Size: 253 bytes
        Folders: 1
        Files: 2

        Folders:
          [0] None (1 blocks)

        Files:
          hello.c
            Size: 77 bytes
            Modified: <TIME>
            Attributes: archive
          welcome.c
            Size: 74 bytes
            Modified: <TIME>
            Attributes: archive
      OUT
    end

    it "prints the integrity report" do
      output, = capture(handler, :test, file)

      expect(output).to eq(<<~OUT)
        Testing #{file}...
        OK: All 2 files passed integrity check
      OUT
    end

    # These used to leak the incidental value of a trailing files.each. Both
    # are documented @return [void], and every other handler already returned
    # nil, so the template normalizes them.
    it "returns nil from #list and #info" do
      _, listed = capture(handler, :list, file)
      _, described = capture(handler, :info, file)

      expect(listed).to be_nil
      expect(described).to be_nil
    end

    it "raises ParseError before printing anything for a truncated cabinet" do
      truncated = Fixtures.for(:cab).edge_case(:partial_shortheader)
      output, error = capture_failure(handler, :test, truncated)

      expect(output).to be_empty
      expect(error).to be_a(Cabriolet::ParseError)
      expect(error.message).to eq("Cannot read CAB header")
    end
  end

  describe "CHM" do
    let(:file) { Fixtures.for(:chm).path(:encints_64bit_both) }
    let(:handler) { Cabriolet::CHM::CommandHandler.new(verbose: false) }

    it "prints the CHM listing" do
      output, = capture(handler, :list, file)

      expect(output).to eq(<<~OUT)
        CHM File: #{file}
        Version: 2
        Language: 1033
        Chunks: 1, Chunk Size: 4096

        Files:
          good00 (127 bytes, Uncompressed)
          good01 (128 bytes, Uncompressed)
          good02 (16383 bytes, Uncompressed)
          good03 (16384 bytes, Uncompressed)
          good04 (2097151 bytes, Uncompressed)
          good05 (2097152 bytes, Uncompressed)
          good06 (268435455 bytes, Uncompressed)
          good07 (268435456 bytes, Uncompressed)
          good08 (2147483647 bytes, Uncompressed)
          good09 (2147483648 bytes, Uncompressed)
          good10 (34359738367 bytes, Uncompressed)
          good11 (34359738368 bytes, Uncompressed)
          good12 (4398046511103 bytes, Uncompressed)
          good13 (4398046511104 bytes, Uncompressed)
          good14 (562949953421311 bytes, Uncompressed)
          good15 (562949953421312 bytes, Uncompressed)
          good16 (72057594037927935 bytes, Uncompressed)
          good17 (72057594037927936 bytes, Uncompressed)
          good18 (9223372036854775807 bytes, Uncompressed)
      OUT
    end

    def expected_chm_info(file)
      <<~OUT
        CHM File Information
        ==================================================
        Filename: #{file}
        Version: 2
        Language ID: 1033
        Timestamp: 0
        Size: 4292 bytes

        Directory:
          Offset: 196
          Chunks: 1
          Chunk Size: 4096
          First PMGL: 0
          Last PMGL: 0

        Sections:
          Section 0 (Uncompressed): offset 4292
          Section 1 (MSCompressed): LZX compression

        Files: 19 regular, 0 system

        Regular Files:
          good00
            Size: 127 bytes (Sec0)
          good01
            Size: 128 bytes (Sec0)
          good02
            Size: 16383 bytes (Sec0)
          good03
            Size: 16384 bytes (Sec0)
          good04
            Size: 2097151 bytes (Sec0)
          good05
            Size: 2097152 bytes (Sec0)
          good06
            Size: 268435455 bytes (Sec0)
          good07
            Size: 268435456 bytes (Sec0)
          good08
            Size: 2147483647 bytes (Sec0)
          good09
            Size: 2147483648 bytes (Sec0)
          good10
            Size: 34359738367 bytes (Sec0)
          good11
            Size: 34359738368 bytes (Sec0)
          good12
            Size: 4398046511103 bytes (Sec0)
          good13
            Size: 4398046511104 bytes (Sec0)
          good14
            Size: 562949953421311 bytes (Sec0)
          good15
            Size: 562949953421312 bytes (Sec0)
          good16
            Size: 72057594037927935 bytes (Sec0)
          good17
            Size: 72057594037927936 bytes (Sec0)
          good18
            Size: 9223372036854775807 bytes (Sec0)
      OUT
    end

    it "prints detailed CHM information" do
      output, = capture(handler, :info, file)

      expect(output).to eq(expected_chm_info(file))
    end

    it "prints the integrity report" do
      output, = capture(handler, :test, file)

      expect(output).to eq(<<~OUT)
        Testing #{file}...
        OK: CHM file structure is valid (19 files)
      OUT
    end
  end

  describe "HLP" do
    let(:file) { Fixtures.for(:hlp).path(:masmlib) }
    let(:handler) { Cabriolet::HLP::CommandHandler.new(verbose: false) }

    it "prints the HLP listing" do
      output, = capture(handler, :list, file)

      expect(output).to eq(<<~OUT)
        HLP File: #{file}
        Format: WinHelp 4

        Files:
          (File listing not available for this format)
      OUT
    end

    it "prints detailed HLP information" do
      output, = capture(handler, :info, file)

      expect(output).to eq(<<~OUT)
        HLP File Information
        ==================================================
        Filename: #{file}
        Format: WinHelp 4
        Size: 108865 bytes
      OUT
    end

    it "prints the integrity report" do
      output, = capture(handler, :test, file)

      expect(output).to eq(<<~OUT)
        Testing #{file}...
        OK: HLP file structure is valid (WinHelp 4 format)
      OUT
    end
  end

  describe "KWAJ" do
    let(:file) { Fixtures.for(:kwaj).path(:f00) }
    let(:handler) { Cabriolet::KWAJ::CommandHandler.new(verbose: false) }

    it "prints the same report for #list and #info" do
      listing, = capture(handler, :list, file)
      described, = capture(handler, :info, file)

      expect(listing).to eq(<<~OUT)
        KWAJ File Information
        ==================================================
        Filename: #{file}
        Compression: None
        Data offset: 14 bytes
        Uncompressed size: unknown bytes
      OUT
      expect(described).to eq(listing)
    end

    it "prints the integrity report" do
      output, = capture(handler, :test, file)

      expect(output).to eq(<<~OUT)
        Testing #{file}...
        OK: KWAJ file structure is valid
        Compression: None
        Data offset: 14 bytes
        Uncompressed size: unknown bytes
      OUT
    end

    it "raises ParseError before printing anything for a malformed header" do
      malformed = Fixtures.for(:kwaj).edge_case(:f04)

      read_commands.each do |command|
        output, error = capture_failure(handler, command, malformed)

        expect(output).to be_empty
        expect(error).to be_a(Cabriolet::ParseError)
        expect(error.message).to eq("File extension not null-terminated")
      end
    end
  end

  describe "LIT" do
    let(:file) { Fixtures.for(:lit).path(:bill) }
    let(:handler) { Cabriolet::LIT::CommandHandler.new(verbose: false) }

    def expected_lit_listing
      <<~OUT
        LIT File: bill.lit
        Version: 1
        Language ID: 0x409
        DRM Protected: No

        Files:
          /data/ (0 bytes)
          /data/bill2/ (0 bytes)
          /data/bill2/content (3286 bytes)
          /data/~cov0001 (4855 bytes)
          /data/~cov0002 (40423 bytes)
          /data/~cov0003 (14214 bytes)
          /data/~cov0004 (2245 bytes)
          /data/~cov0005 (17929 bytes)
          /data/~cov0006/ (0 bytes)
          /data/~cov0006/content (422 bytes)
          /DRMStorage/ (0 bytes)
          /DRMStorage/DRMSealed (16 bytes)
          /DRMStorage/DRMSource (24 bytes)
          /DRMStorage/ValidationStream (8 bytes)
          /manifest (276 bytes)
          /meta (1232 bytes)
          /pb1 (24 bytes)
          /pb2 (20 bytes)
          /pb3 (1 bytes)
          ::DataSpace/NameList (120 bytes)
          ::DataSpace/Storage/EbEncryptDS/Content (1968 bytes)
          ::DataSpace/Storage/EbEncryptDS/ControlData (48 bytes)
          ::DataSpace/Storage/EbEncryptDS/SpanInfo (16 bytes)
          ::DataSpace/Storage/EbEncryptDS/Transform/List (32 bytes)
          ::DataSpace/Storage/EbEncryptDS/Transform/{0A9007C6-4076-11D3-8789-0000F8105754}/InstanceData/ (0 bytes)
          ::DataSpace/Storage/EbEncryptDS/Transform/{0A9007C6-4076-11D3-8789-0000F8105754}/InstanceData/ResetTable (48 bytes)
          ::DataSpace/Storage/EbEncryptDS/Transform/{67F6E4A2-60BF-11D3-8540-00C04F58C3CF}/InstanceData/ (0 bytes)
          ::DataSpace/Storage/EbEncryptOnlyDS/Content (8 bytes)
          ::DataSpace/Storage/EbEncryptOnlyDS/ControlData (16 bytes)
          ::DataSpace/Storage/EbEncryptOnlyDS/SpanInfo (8 bytes)
          ::DataSpace/Storage/EbEncryptOnlyDS/Transform/List (16 bytes)
          ::DataSpace/Storage/EbEncryptOnlyDS/Transform/{67F6E4A2-60BF-11D3-8540-00C04F58C3CF}/InstanceData/ (0 bytes)
          ::DataSpace/Storage/MSCompressed/Content (0 bytes)
          ::DataSpace/Storage/MSCompressed/ControlData (32 bytes)
          ::DataSpace/Storage/MSCompressed/SpanInfo (8 bytes)
          ::DataSpace/Storage/MSCompressed/Transform/List (16 bytes)
          ::DataSpace/Storage/MSCompressed/Transform/{0A9007C6-4076-11D3-8789-0000F8105754}/InstanceData/ (0 bytes)
          ::DataSpace/Storage/MSCompressed/Transform/{0A9007C6-4076-11D3-8789-0000F8105754}/InstanceData/ResetTable (0 bytes)
          ::Transform/{0A9007C6-4076-11D3-8789-0000F8105754}/ (0 bytes)
          ::Transform/{67F6E4A2-60BF-11D3-8540-00C04F58C3CF}/ (0 bytes)
      OUT
    end

    it "prints the LIT header and file listing" do
      output, = capture(handler, :list, file)

      expect(output).to eq(expected_lit_listing)
    end

    it "prints detailed LIT information" do
      output, = capture(handler, :info, file)

      expect(output).to eq(<<~OUT)
        LIT File Information
        ==================================================
        Filename: #{file}
        Version: 1
        Language ID: 0x409
        Creator ID: 0

        DRM Protection: None

        Sections: 4
          [0] MSCompressed
              Transforms: {4C4C4F41-01CD-0000-0000-000000000000}
          [1] EbEncryptOnlyDS
              Transforms: {FFFFFFFF-FFFF-FFFF-0100-000000000000}

        Files: 40

        Manifest mappings: 0
      OUT
    end

    # The Validator reads 4 magic bytes and compares them against the 8-byte
    # "ITOLITLS" signature, so every LIT file fails the integrity check and
    # #test never reaches its DRM report. Characterizing, not endorsing.
    it "prints the banner then fails the integrity check" do
      output, error = capture_failure(handler, :test, file)

      expect(output).to eq(<<~OUT)
        Testing #{file}...
        ERROR: Invalid magic bytes for lit format
      OUT
      expect(error).to be_a(Cabriolet::Error)
      expect(error.message).to eq("Integrity check failed")
    end
  end

  describe "OAB" do
    let(:file) { Fixtures.for(:oab).path(:simple) }
    let(:handler) { Cabriolet::OAB::CommandHandler.new(verbose: false) }

    it "prints the same report for #list and #info" do
      listing, = capture(handler, :list, file)
      described, = capture(handler, :info, file)

      expect(listing).to eq(<<~OUT)
        OAB File Information
        ==================================================
        Filename: #{file}
        Type: Full OAB file
        Version: 3.1
        Target size: 35 bytes
        Block max: 32768 bytes
      OUT
      expect(described).to eq(listing)
    end

    # OAB is the one format whose #test skips validate_integrity. The Validator
    # has no magic bytes registered for :oab, so it rejects every OAB file; any
    # format that ran it would abort the way LIT does. OAB reporting OK is
    # therefore proof it never called it.
    it "reports OK even though the validator rejects the file" do
      report = Cabriolet::Validator.new(
        file, level: Cabriolet::Validator::LEVEL_QUICK
      ).validate
      expect(report).not_to be_valid
      expect(report.errors).to eq(["Invalid magic bytes for oab format"])

      output, = capture(handler, :test, file)

      expect(output).to eq(<<~OUT)
        Testing #{file}...
        OK: OAB full file structure is valid
        Version: 3.1
        Target size: 35 bytes
        Block max: 32768 bytes
      OUT
    end
  end

  describe "SZDD" do
    let(:file) { Fixtures.for(:szdd).path(:uninstall) }
    let(:handler) { Cabriolet::SZDD::CommandHandler.new(verbose: false) }

    it "prints the same report for #list and #info" do
      listing, = capture(handler, :list, file)
      described, = capture(handler, :info, file)

      expect(listing).to eq(<<~OUT)
        SZDD File Information
        ==================================================
        Filename: #{file}
        Format: NORMAL
        Uncompressed size: 40960 bytes
        Missing character: 'e'
        Suggested filename: UNINSTAL.EXE
      OUT
      expect(described).to eq(listing)
    end

    it "prints the integrity report" do
      output, = capture(handler, :test, file)

      expect(output).to eq(<<~OUT)
        Testing #{file}...
        OK: SZDD file structure is valid
        Format: NORMAL
        Uncompressed size: 40960 bytes
      OUT
    end
  end

  describe "a missing file" do
    {
      cab: Cabriolet::CAB::CommandHandler,
      chm: Cabriolet::CHM::CommandHandler,
      hlp: Cabriolet::HLP::CommandHandler,
      kwaj: Cabriolet::KWAJ::CommandHandler,
      lit: Cabriolet::LIT::CommandHandler,
      oab: Cabriolet::OAB::CommandHandler,
      szdd: Cabriolet::SZDD::CommandHandler,
    }.each do |format, handler_class|
      it "raises ArgumentError before printing anything for #{format}" do
        handler = handler_class.new(verbose: false)
        missing = "/nonexistent/file.#{format}"

        read_commands.each do |command|
          output, error = capture_failure(handler, command, missing)

          expect(output).to be_empty
          expect(error).to be_a(ArgumentError)
          expect(error.message).to eq("File does not exist: #{missing}")
        end
      end
    end
  end
end
