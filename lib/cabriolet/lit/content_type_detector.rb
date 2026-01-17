# frozen_string_literal: true

module Cabriolet
  module LIT
    # Detects content type and file group for LIT files
    class ContentTypeDetector
      # Guess content type from filename
      #
      # @param filename [String] Filename to analyze
      # @return [String] MIME content type
      def self.content_type(filename)
        ext = ::File.extname(filename).downcase
        case ext
        when ".html", ".htm"
          "text/html"
        when ".css"
          "text/css"
        when ".jpg", ".jpeg"
          "image/jpeg"
        when ".png"
          "image/png"
        when ".gif"
          "image/gif"
        when ".txt"
          "text/plain"
        else
          "application/octet-stream"
        end
      end

      # Guess file group (0=HTML spine, 1=HTML other, 2=CSS, 3=Images)
      #
      # @param filename [String] Filename to analyze
      # @return [Integer] Group number
      def self.file_group(filename)
        ext = ::File.extname(filename).downcase
        case ext
        when ".html", ".htm"
          0 # HTML spine (simplification - could be group 1 for non-spine)
        when ".css"
          2 # CSS
        when ".jpg", ".jpeg", ".png", ".gif"
          3 # Images
        else
          1 # Other
        end
      end
    end
  end
end
