# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Models::CHMFile do
  let(:file) { described_class.new }

  describe "#initialize" do
    it "initializes with default values" do
      expect(file.next_file).to be_nil
      expect(file.section).to be_nil
      expect(file.offset).to eq(0)
      expect(file.length).to eq(0)
      expect(file.filename).to eq("")
    end
  end

  describe "#system_file?" do
    it "returns true for system files" do
      file.filename = "::DataSpace/Storage/MSCompressed/Content"
      expect(file.system_file?).to be true
    end

    it "returns false for regular files" do
      file.filename = "index.html"
      expect(file.system_file?).to be false
    end
  end

  describe "#empty?" do
    it "returns true for zero-length files" do
      file.length = 0
      expect(file.empty?).to be true
    end

    it "returns false for non-zero length files" do
      file.length = 100
      expect(file.empty?).to be false
    end
  end
end
