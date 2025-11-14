# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Models::File do
  subject(:file) { described_class.new }

  describe "#initialize" do
    it "initializes with default values" do
      expect(file.filename).to be_nil
      expect(file.length).to eq(0)
      expect(file.offset).to eq(0)
      expect(file.folder).to be_nil
      expect(file.folder_index).to eq(0)
      expect(file.attribs).to eq(0)
      expect(file.next_file).to be_nil
    end

    it "initializes with default date/time values" do
      expect(file.time_h).to eq(0)
      expect(file.time_m).to eq(0)
      expect(file.time_s).to eq(0)
      expect(file.date_d).to eq(1)
      expect(file.date_m).to eq(1)
      expect(file.date_y).to eq(1980)
    end
  end

  describe "#parse_datetime" do
    it "parses valid date and time" do
      # 0x5011 = day=17, month=0, year=40 (2020)
      # 0x73D6 = hour=14, minute=30, second=22 (44 seconds)
      date_bits = 0x5011
      time_bits = 0x73D6

      file.parse_datetime(date_bits, time_bits)

      expect(file.date_y).to eq(2020) # 40 + 1980
      expect(file.date_m).to eq(0) # Month is 0 in this test data
      expect(file.date_d).to eq(17) # Day is 17
      expect(file.time_h).to eq(14)
      expect(file.time_m).to eq(30)
      expect(file.time_s).to eq(44)
    end

    it "extracts hour from time bits" do
      # Hour is bits 11-15
      time_bits = (23 << 11) # 23:00:00
      file.parse_datetime(0, time_bits)
      expect(file.time_h).to eq(23)
    end

    it "extracts minute from time bits" do
      # Minute is bits 5-10
      time_bits = (45 << 5) # 00:45:00
      file.parse_datetime(0, time_bits)
      expect(file.time_m).to eq(45)
    end

    it "extracts second from time bits" do
      # Second is bits 0-4, stored as /2
      time_bits = 29 # 00:00:58 (29*2)
      file.parse_datetime(0, time_bits)
      expect(file.time_s).to eq(58)
    end

    it "extracts day from date bits" do
      # Day is bits 0-4
      date_bits = 31 # Day 31
      file.parse_datetime(date_bits, 0)
      expect(file.date_d).to eq(31)
    end

    it "extracts month from date bits" do
      # Month is bits 5-8
      date_bits = (12 << 5) # December
      file.parse_datetime(date_bits, 0)
      expect(file.date_m).to eq(12)
    end

    it "extracts year from date bits" do
      # Year is bits 9-15, added to 1980
      date_bits = (25 << 9) # 2005 (1980 + 25)
      file.parse_datetime(date_bits, 0)
      expect(file.date_y).to eq(2005)
    end
  end

  describe "#modification_time" do
    it "returns a Time object for valid date/time" do
      # Set to January 1, 2020, 12:00:00
      file.date_y = 2020
      file.date_m = 1
      file.date_d = 1
      file.time_h = 12
      file.time_m = 0
      file.time_s = 0

      time = file.modification_time
      expect(time).to be_a(Time)
      expect(time.year).to eq(2020)
      expect(time.month).to eq(1)
      expect(time.day).to eq(1)
      expect(time.hour).to eq(12)
    end

    it "returns nil for invalid date" do
      file.date_y = 2020
      file.date_m = 13 # Invalid month
      file.date_d = 1

      expect(file.modification_time).to be_nil
    end

    it "returns nil for invalid time" do
      file.date_y = 2020
      file.date_m = 1
      file.date_d = 1
      file.time_h = 25 # Invalid hour

      expect(file.modification_time).to be_nil
    end
  end

  describe "#utf8_filename?" do
    context "when ATTRIB_UTF_NAME is set" do
      it "returns true" do
        file.attribs = Cabriolet::Constants::ATTRIB_UTF_NAME
        expect(file.utf8_filename?).to be(true)
      end
    end

    context "when ATTRIB_UTF_NAME is not set" do
      it "returns false" do
        file.attribs = 0
        expect(file.utf8_filename?).to be(false)
      end
    end
  end

  describe "#readonly?" do
    context "when ATTRIB_READONLY is set" do
      it "returns true" do
        file.attribs = Cabriolet::Constants::ATTRIB_READONLY
        expect(file.readonly?).to be(true)
      end
    end

    context "when ATTRIB_READONLY is not set" do
      it "returns false" do
        file.attribs = 0
        expect(file.readonly?).to be(false)
      end
    end
  end

  describe "#hidden?" do
    context "when ATTRIB_HIDDEN is set" do
      it "returns true" do
        file.attribs = Cabriolet::Constants::ATTRIB_HIDDEN
        expect(file.hidden?).to be(true)
      end
    end

    context "when ATTRIB_HIDDEN is not set" do
      it "returns false" do
        file.attribs = 0
        expect(file.hidden?).to be(false)
      end
    end
  end

  describe "#system?" do
    context "when ATTRIB_SYSTEM is set" do
      it "returns true" do
        file.attribs = Cabriolet::Constants::ATTRIB_SYSTEM
        expect(file.system?).to be(true)
      end
    end

    context "when ATTRIB_SYSTEM is not set" do
      it "returns false" do
        file.attribs = 0
        expect(file.system?).to be(false)
      end
    end
  end

  describe "#archived?" do
    context "when ATTRIB_ARCH is set" do
      it "returns true" do
        file.attribs = Cabriolet::Constants::ATTRIB_ARCH
        expect(file.archived?).to be(true)
      end
    end

    context "when ATTRIB_ARCH is not set" do
      it "returns false" do
        file.attribs = 0
        expect(file.archived?).to be(false)
      end
    end
  end

  describe "#executable?" do
    context "when ATTRIB_EXEC is set" do
      it "returns true" do
        file.attribs = Cabriolet::Constants::ATTRIB_EXEC
        expect(file.executable?).to be(true)
      end
    end

    context "when ATTRIB_EXEC is not set" do
      it "returns false" do
        file.attribs = 0
        expect(file.executable?).to be(false)
      end
    end
  end

  describe "#continued_from_prev?" do
    context "when folder_index is FOLDER_CONTINUED_FROM_PREV" do
      it "returns true" do
        file.folder_index = Cabriolet::Constants::FOLDER_CONTINUED_FROM_PREV
        expect(file.continued_from_prev?).to be(true)
      end
    end

    context "when folder_index is FOLDER_CONTINUED_PREV_AND_NEXT" do
      it "returns true" do
        file.folder_index = Cabriolet::Constants::FOLDER_CONTINUED_PREV_AND_NEXT
        expect(file.continued_from_prev?).to be(true)
      end
    end

    context "when folder_index is normal" do
      it "returns false" do
        file.folder_index = 0
        expect(file.continued_from_prev?).to be(false)
      end
    end

    context "when folder_index is FOLDER_CONTINUED_TO_NEXT" do
      it "returns false" do
        file.folder_index = Cabriolet::Constants::FOLDER_CONTINUED_TO_NEXT
        expect(file.continued_from_prev?).to be(false)
      end
    end
  end

  describe "#continued_to_next?" do
    context "when folder_index is FOLDER_CONTINUED_TO_NEXT" do
      it "returns true" do
        file.folder_index = Cabriolet::Constants::FOLDER_CONTINUED_TO_NEXT
        expect(file.continued_to_next?).to be(true)
      end
    end

    context "when folder_index is FOLDER_CONTINUED_PREV_AND_NEXT" do
      it "returns true" do
        file.folder_index = Cabriolet::Constants::FOLDER_CONTINUED_PREV_AND_NEXT
        expect(file.continued_to_next?).to be(true)
      end
    end

    context "when folder_index is normal" do
      it "returns false" do
        file.folder_index = 0
        expect(file.continued_to_next?).to be(false)
      end
    end

    context "when folder_index is FOLDER_CONTINUED_FROM_PREV" do
      it "returns false" do
        file.folder_index = Cabriolet::Constants::FOLDER_CONTINUED_FROM_PREV
        expect(file.continued_to_next?).to be(false)
      end
    end
  end

  describe "#to_s" do
    it "returns filename and size" do
      file.filename = "test.txt"
      file.length = 1024
      expect(file.to_s).to eq("test.txt (1024 bytes)")
    end

    it "handles nil filename" do
      file.length = 512
      expect(file.to_s).to eq(" (512 bytes)")
    end
  end

  describe "attribute accessors" do
    it "allows setting and getting filename" do
      file.filename = "document.pdf"
      expect(file.filename).to eq("document.pdf")
    end

    it "allows setting and getting length" do
      file.length = 2048
      expect(file.length).to eq(2048)
    end

    it "allows setting and getting offset" do
      file.offset = 512
      expect(file.offset).to eq(512)
    end

    it "allows setting and getting folder" do
      folder = double("folder")
      file.folder = folder
      expect(file.folder).to eq(folder)
    end

    it "allows setting and getting folder_index" do
      file.folder_index = 5
      expect(file.folder_index).to eq(5)
    end

    it "allows setting and getting attribs" do
      file.attribs = 0xFF
      expect(file.attribs).to eq(0xFF)
    end

    it "allows setting and getting next_file" do
      next_file = described_class.new
      file.next_file = next_file
      expect(file.next_file).to eq(next_file)
    end
  end

  describe "combined attributes" do
    it "handles multiple attribute flags" do
      file.attribs = Cabriolet::Constants::ATTRIB_READONLY |
        Cabriolet::Constants::ATTRIB_HIDDEN |
        Cabriolet::Constants::ATTRIB_SYSTEM

      expect(file.readonly?).to be(true)
      expect(file.hidden?).to be(true)
      expect(file.system?).to be(true)
      expect(file.archived?).to be(false)
      expect(file.executable?).to be(false)
    end

    it "handles all attributes set" do
      file.attribs = Cabriolet::Constants::ATTRIB_READONLY |
        Cabriolet::Constants::ATTRIB_HIDDEN |
        Cabriolet::Constants::ATTRIB_SYSTEM |
        Cabriolet::Constants::ATTRIB_ARCH |
        Cabriolet::Constants::ATTRIB_EXEC |
        Cabriolet::Constants::ATTRIB_UTF_NAME

      expect(file.readonly?).to be(true)
      expect(file.hidden?).to be(true)
      expect(file.system?).to be(true)
      expect(file.archived?).to be(true)
      expect(file.executable?).to be(true)
      expect(file.utf8_filename?).to be(true)
    end
  end
end
