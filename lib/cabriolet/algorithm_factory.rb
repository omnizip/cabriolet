# frozen_string_literal: true

module Cabriolet
  # Factory for creating and managing compression/decompression algorithms
  #
  # The AlgorithmFactory provides a centralized registry for compression and
  # decompression algorithms. It handles algorithm registration, validation,
  # instantiation, and type normalization.
  #
  # @example Register and create an algorithm
  #   factory = AlgorithmFactory.new
  #   factory.register(:custom, CustomCompressor, category: :compressor)
  #   algorithm = factory.create(:custom, :compressor, io, input, output, 4096)
  #
  # @example Use with integer type constants
  #   # Constants::COMP_TYPE_MSZIP (1) is normalized to :mszip
  #   algorithm = factory.create(1, :decompressor, io, input, output, 4096)
  class AlgorithmFactory
    # @return [Hash] Registry of algorithms by category and type
    attr_reader :algorithms

    # Initialize a new algorithm factory
    #
    # @param auto_register [Boolean] Whether to automatically register
    #   built-in algorithms
    def initialize(auto_register: true)
      @algorithms = { compressor: {}, decompressor: {} }
      register_built_in_algorithms if auto_register
    end

    # Register an algorithm in the factory
    #
    # @param type [Symbol] Algorithm type (:none, :mszip, :lzx, :quantum,
    #   :lzss)
    # @param algorithm_class [Class] Algorithm class (must inherit from
    #   Compressors::Base or Decompressors::Base)
    # @param options [Hash] Registration options
    # @option options [Symbol] :category Required - :compressor or
    #   :decompressor
    # @option options [Integer] :priority Priority for selection (default: 0)
    # @option options [Symbol, nil] :format Format restriction (optional)
    #
    # @return [self] Returns self for method chaining
    #
    # @raise [ArgumentError] If category is invalid
    # @raise [ArgumentError] If algorithm_class doesn't inherit from Base
    #
    # @example Register a custom compressor
    #   factory.register(:custom, MyCompressor,
    #                    category: :compressor, priority: 10)
    #
    # @example Chain multiple registrations
    #   factory
    #     .register(:algo1, Algo1, category: :compressor)
    #     .register(:algo2, Algo2, category: :decompressor)
    def register(type, algorithm_class, **options)
      category = options[:category]
      validate_category!(category)
      validate_algorithm_class!(algorithm_class, category)

      @algorithms[category][type] = {
        class: algorithm_class,
        priority: options.fetch(:priority, 0),
        format: options[:format],
      }

      self
    end

    # Create an instance of a registered algorithm
    #
    # @param type [Symbol, Integer] Algorithm type (symbol or constant)
    # @param category [Symbol] Category (:compressor or :decompressor)
    # @param io_system [System::IOSystem] I/O system for operations
    # @param input [System::FileHandle, System::MemoryHandle] Input handle
    # @param output [System::FileHandle, System::MemoryHandle] Output handle
    # @param buffer_size [Integer] Buffer size for I/O operations
    # @param kwargs [Hash] Additional keyword arguments for algorithm
    #
    # @return [Compressors::Base, Decompressors::Base] Algorithm instance
    #
    # @raise [ArgumentError] If category is invalid
    # @raise [UnsupportedFormatError] If algorithm type not registered
    #
    # @example Create a decompressor
    #   decompressor = factory.create(:mszip, :decompressor,
    #                                 io, input, output, 4096)
    #
    # @example Create with integer constant
    #   # Constants::COMP_TYPE_LZX (3) -> :lzx
    #   compressor = factory.create(3, :compressor,
    #                               io, input, output, 8192)
    def create(type, category, io_system, input, output, buffer_size,
               **kwargs)
      validate_category!(category)

      normalized_type = normalize_type(type)
      algorithm_info = @algorithms[category][normalized_type]

      unless algorithm_info
        raise UnsupportedFormatError,
              "Unknown #{category} algorithm: #{normalized_type}"
      end

      algorithm_info[:class].new(io_system, input, output, buffer_size,
                                 **kwargs)
    end

    # Check if an algorithm is registered
    #
    # @param type [Symbol] Algorithm type
    # @param category [Symbol] Category (:compressor or :decompressor)
    #
    # @return [Boolean] True if registered, false otherwise
    #
    # @example Check registration
    #   factory.registered?(:mszip, :compressor) #=> true
    #   factory.registered?(:unknown, :compressor) #=> false
    def registered?(type, category)
      @algorithms[category]&.key?(type) || false
    end

    # List registered algorithms
    #
    # @param category [Symbol, nil] Optional category filter
    #
    # @return [Hash] Hash of registered algorithms
    #
    # @example List all algorithms
    #   factory.list
    #   #=> { compressor: { mszip: {...}, lzx: {...} },
    #   #     decompressor: { none: {...}, mszip: {...} } }
    #
    # @example List compressors only
    #   factory.list(:compressor)
    #   #=> { mszip: {...}, lzx: {...}, quantum: {...}, lzss: {...} }
    def list(category = nil)
      if category.nil?
        {
          compressor: @algorithms[:compressor].dup,
          decompressor: @algorithms[:decompressor].dup,
        }
      else
        @algorithms[category]&.dup || {}
      end
    end

    # Unregister an algorithm
    #
    # @param type [Symbol] Algorithm type to remove
    # @param category [Symbol] Category (:compressor or :decompressor)
    #
    # @return [Boolean] True if removed, false if not found
    #
    # @example Unregister an algorithm
    #   factory.unregister(:mszip, :compressor) #=> true
    #   factory.unregister(:unknown, :compressor) #=> false
    # rubocop:disable Naming/PredicatePrefix
    def unregister(type, category)
      !@algorithms[category].delete(type).nil?
    end
    # rubocop:enable Naming/PredicatePrefix

    private

    # Register all built-in compression and decompression algorithms
    #
    # Registers 5 decompressors (none, lzss, mszip, lzx, quantum) and
    # 4 compressors (lzss, mszip, lzx, quantum).
    #
    # @return [void]
    def register_built_in_algorithms
      # Register decompressors (5 total)
      register(:none, Decompressors::None, category: :decompressor)
      register(:lzss, Decompressors::LZSS, category: :decompressor)
      register(:mszip, Decompressors::MSZIP, category: :decompressor)
      register(:lzx, Decompressors::LZX, category: :decompressor)
      register(:quantum, Decompressors::Quantum, category: :decompressor)

      # Register compressors (4 total - no 'none' compressor)
      register(:lzss, Compressors::LZSS, category: :compressor)
      register(:mszip, Compressors::MSZIP, category: :compressor)
      register(:lzx, Compressors::LZX, category: :compressor)
      register(:quantum, Compressors::Quantum, category: :compressor)
    end

    # Normalize algorithm type from integer constant to symbol
    #
    # @param type [Symbol, Integer] Type to normalize
    #
    # @return [Symbol] Normalized type symbol
    #
    # @example Normalize integer constants
    #   normalize_type(0) #=> :none
    #   normalize_type(1) #=> :mszip
    #   normalize_type(2) #=> :quantum
    #   normalize_type(3) #=> :lzx
    #   normalize_type(:lzss) #=> :lzss
    def normalize_type(type)
      return type if type.is_a?(Symbol)

      case type
      when Constants::COMP_TYPE_NONE then :none
      when Constants::COMP_TYPE_MSZIP then :mszip
      when Constants::COMP_TYPE_QUANTUM then :quantum
      when Constants::COMP_TYPE_LZX then :lzx
      else
        raise UnsupportedFormatError,
              "Unsupported compression type: #{type}"
      end
    end

    # Validate that category is valid
    #
    # @param category [Symbol] Category to validate
    #
    # @raise [ArgumentError] If category is not :compressor or :decompressor
    #
    # @return [void]
    def validate_category!(category)
      valid_categories = %i[compressor decompressor]
      return if valid_categories.include?(category)

      raise ArgumentError,
            "Invalid category: #{category}. " \
            "Must be :compressor or :decompressor"
    end

    # Validate that algorithm class inherits from appropriate base class
    #
    # @param klass [Class] Algorithm class to validate
    # @param category [Symbol] Category (:compressor or :decompressor)
    #
    # @raise [ArgumentError] If class doesn't inherit from correct base
    #
    # @return [void]
    def validate_algorithm_class!(klass, category)
      base_class = if category == :compressor
                     Compressors::Base
                   else
                     Decompressors::Base
                   end

      return if klass < base_class

      raise ArgumentError,
            "#{klass} must inherit from #{base_class}"
    end
  end
end
