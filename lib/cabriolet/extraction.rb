# frozen_string_literal: true

module Cabriolet
  module Extraction
    autoload :FileOperations, "cabriolet/extraction/file_operations"
    autoload :BaseExtractor, "cabriolet/extraction/base_extractor"
    autoload :Extractor, "cabriolet/extraction/extractor"
    autoload :FileExtractionWork, "cabriolet/extraction/file_extraction_work"
    autoload :FileExtractionWorker, "cabriolet/extraction/file_extraction_worker"
  end
end
