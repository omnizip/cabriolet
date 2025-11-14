# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet do
  it "has a version number" do
    expect(Cabriolet::VERSION).not_to be_nil
  end

  describe ".verbose" do
    it "defaults to false" do
      expect(described_class.verbose).to be false
    end

    it "can be set to true" do
      described_class.verbose = true
      expect(described_class.verbose).to be true
      described_class.verbose = false
    end
  end

  describe ".default_buffer_size" do
    it "defaults to 4096" do
      expect(described_class.default_buffer_size).to eq(4096)
    end
  end
end
