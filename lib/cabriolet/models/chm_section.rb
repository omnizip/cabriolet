# frozen_string_literal: true

module Cabriolet
  module Models
    # Base class for CHM sections
    class CHMSection
      attr_accessor :chm, :id

      def initialize(chm, id)
        @chm = chm
        @id = id
      end
    end

    # Section 0: Uncompressed data
    class CHMSecUncompressed < CHMSection
      attr_accessor :offset

      def initialize(chm)
        super(chm, 0)
        @offset = 0
      end
    end

    # Section 1: MSCompressed (LZX) data
    class CHMSecMSCompressed < CHMSection
      attr_accessor :content, :control, :spaninfo, :rtable

      def initialize(chm)
        super(chm, 1)
        @content = nil
        @control = nil
        @spaninfo = nil
        @rtable = nil
      end
    end
  end
end
