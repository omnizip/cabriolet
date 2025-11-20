# Cabriolet Architecture Plan

## Overview

**Cabriolet** is a pure Ruby gem for extracting Microsoft compression formats,
focusing primarily on CAB (Cabinet) files. This implementation is a Ruby port of
libmspack and cabextract.

## Goals

1. **Pure Ruby Implementation**: No C extensions, fully portable
2. **Full CAB Format Support**: Handle all compression methods (MSZIP, LZX, Quantum)
3. **Extensible Design**: Easy to add support for CHM, LIT, HLP formats later
4. **Well-Tested**: Comprehensive test coverage using libmspack test files
5. **Performance**: Optimized for reasonable performance while maintaining readability

## Source Material

- **libmspack**: https://github.com/kyz/libmspack (LGPL 2.1)
- **Location**: `/Users/mulgogi/src/external/libmspack`
- **Primary Files to Port**:
  - `mspack/cabd.c` - CAB decompressor
  - `mspack/lzxd.c` - LZX decompression
  - `mspack/mszipd.c` - MSZIP decompression
  - `mspack/qtmd.c` - Quantum decompression
  - `mspack/lzssd.c` - LZSS decompression
  - `mspack/system.c` - I/O abstraction

## Architecture

### High-Level Structure

```
┌────────────────────────────────────────────────────────┐
│                    Cabriolet Gem                       │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │     CLI      │  │   Cabinet    │  │   Models     │  │
│  │    Tool      │  │  Extractor   │  │   (Lutaml)   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│         │                 │                  │         │
│         └─────────────────┴──────────────────┘         │
│                           │                            │
│  ┌────────────────────────┴─────────────────────────┐  │
│  │         CAB Decompressor (Core)                  │  │
│  ├──────────────────────────────────────────────────┤  │
│  │  • Cabinet Parser                                │  │
│  │  • Folder/File Management                        │  │
│  │  • Decompression Strategy Selection              │  │
│  └──────────────────────────────────────────────────┘  │
│                           │                            │
│  ┌────────────────────────┴─────────────────────────┐  │
│  │      Decompression Algorithms                    │  │
│  ├──────────────────────────────────────────────────┤  │
│  │  • MSZIP (Deflate)                               │  │
│  │  • LZX                                           │  │
│  │  • Quantum                                       │  │
│  │  • LZSS                                          │  │
│  │  • None (Uncompressed)                           │  │
│  └──────────────────────────────────────────────────┘  │
│                           │                            │
│  ┌────────────────────────┴─────────────────────────┐  │
│  │         Foundation Layer                         │  │
│  ├──────────────────────────────────────────────────┤  │
│  │  • System I/O Abstraction                        │  │
│  │  • Binary I/O (Endianness handling)              │  │
│  │  • Bitstream Reader                              │  │
│  │  • Huffman Tree Decoder                          │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### Directory Structure

```
cabriolet/
├── lib/
│   └── cabriolet/
│       ├── version.rb
│       ├── errors.rb
│       ├── constants.rb
│       │
│       ├── system/                    # System abstraction layer
│       │   ├── io_system.rb          # File I/O abstraction
│       │   ├── file_handle.rb        # File handle wrapper
│       │   └── memory_handle.rb      # In-memory I/O
│       │
│       ├── binary/                    # Binary I/O utilities
│       │   ├── reader.rb             # Binary data reader
│       │   ├── bitstream.rb          # Bitstream reader
│       │   └── endian.rb             # Endianness handling
│       │
│       ├── huffman/                   # Huffman decoding
│       │   ├── tree.rb               # Huffman tree structure
│       │   └── decoder.rb            # Huffman decoder
│       │
│       ├── models/                    # Data models (Lutaml::Model)
│       │   ├── cabinet.rb            # Cabinet structure
│       │   ├── folder.rb             # Folder structure
│       │   └── file.rb               # File structure
│       │
│       ├── decompressors/             # Decompression algorithms
│       │   ├── base.rb               # Base decompressor
│       │   ├── none.rb               # No compression
│       │   ├── lzss.rb               # LZSS algorithm
│       │   ├── mszip.rb              # MSZIP (deflate)
│       │   ├── lzx.rb                # LZX algorithm
│       │   └── quantum.rb            # Quantum algorithm
│       │
│       ├── cab/                       # CAB format support
│       │   ├── parser.rb             # CAB file parser
│       │   ├── decompressor.rb       # Main decompressor
│       │   └── extractor.rb          # File extraction
│       │
│       ├── algorithm_factory.rb        # Algorithm factory for extensibility
│       │
│       └── cli.rb                     # Command-line interface
│
├── spec/
│   ├── fixtures/                      # Test CAB files
│   ├── system/
│   ├── binary/
│   ├── huffman/
│   ├── models/
│   ├── decompressors/
│   └── cab/
│
├── exe/
│   └── cabriolet                      # CLI executable
│
├── ARCHITECTURE.md
├── README.adoc
├── CHANGELOG.md
├── LICENSE
├── Gemfile
└── cabriolet.gemspec
```

## Core Components

### Extension Layer (Layer 0): Plugin Architecture

**Location**: `lib/cabriolet/plugin*.rb` and external plugin gems

Enables extensibility without modifying core:

#### Plugin System Components

**Base Plugin** (`lib/cabriolet/plugin.rb`):
- Abstract base class for all plugins
- Required methods: metadata(), setup()
- Optional lifecycle hooks: activate(), deactivate(), cleanup()
- Protected helpers: register_algorithm(), register_format()
- State tracking: discovered → loaded → active → deactivated

**PluginManager** (`lib/cabriolet/plugin_manager.rb`):
- Thread-safe singleton for centralized plugin management
- Plugin discovery via Gem.find_files
- Registry and lifecycle management
- Dependency resolution with topological sort
- Error isolation (plugin failures don't crash core)
- Configuration from ~/.cabriolet/plugins.yml

**PluginValidator** (`lib/cabriolet/plugin_validator.rb`):
- Pre-load validation (inheritance, metadata, versions)
- Safety checks (dangerous method detection)
- Semantic version compatibility checking
- Complete error reporting

#### Plugin Integration

Plugins integrate with existing layers:

```
Plugin Layer (0)
       ↓
Application Layer (1) ← Plugins extend via registration
       ↓
Format Layer (2) ← Plugins can add formats
       ↓
Algorithm Layer (3) ← Plugins register algorithms via AlgorithmFactory
       ↓
Binary I/O Layer (4)
       ↓
System Layer (5)
```

#### Plugin Discovery

1. Gem.find_files('cabriolet/plugins/**/*.rb')
2. Load path scanning
3. Runtime registry
4. Automatic plugin class extraction

#### Example Plugins

See `examples/plugins/` for reference implementations:
- **ROT13 Plugin**: Simple symmetric algorithm
- **BZip2 Plugin**: Advanced compression with configuration

### 1. System Abstraction Layer

**Purpose**: Abstract file I/O, memory management, and system calls

**Files**:
- `system/io_system.rb` - Main I/O abstraction
- `system/file_handle.rb` - File operations wrapper
- `system/memory_handle.rb` - In-memory operations

**Design**:
```ruby
module Cabriolet
  module System
    class IOSystem
      def open(filename, mode)
        # Returns FileHandle or MemoryHandle
      end

      def close(handle)
        # Closes the handle
      end

      def read(handle, bytes)
        # Reads bytes from handle
      end

      def write(handle, data)
        # Writes data to handle
      end

      def seek(handle, offset, whence)
        # Seeks to position
      end

      def tell(handle)
        # Returns current position
      end
    end
  end
end
```

### 2. Binary I/O Layer

**Purpose**: Handle binary data reading with proper endianness

**Files**:
- `binary/reader.rb` - Binary data reader
- `binary/bitstream.rb` - Bitstream operations
- `binary/endian.rb` - Endian conversion utilities

**Key Features**:
- Little-endian integer reading (CAB uses little-endian)
- Bitstream reading for compressed data
- Buffer management

**Design**:
```ruby
module Cabriolet
  module Binary
    class Reader
      def read_uint16_le
        # Read 16-bit little-endian unsigned integer
      end

      def read_uint32_le
        # Read 32-bit little-endian unsigned integer
      end

      def read_bytes(count)
        # Read raw bytes
      end
    end

    class Bitstream
      def initialize(io_system, file_handle, buffer_size)
        # Initialize bitstream reader
      end

      def read_bits(num_bits)
        # Read specified number of bits
      end

      def byte_align
        # Align to byte boundary
      end
    end
  end
end
```

### 3. Huffman Decoding

**Purpose**: Decode Huffman-encoded data streams

**Files**:
- `huffman/tree.rb` - Huffman tree construction
- `huffman/decoder.rb` - Decoding logic

**Design**:
```ruby
module Cabriolet
  module Huffman
    class Tree
      def initialize(lengths, num_symbols)
        # Build Huffman tree from code lengths
      end

      def build_table(table_bits)
        # Build fast decode table
      end
    end

    class Decoder
      def decode_symbol(bitstream, table)
        # Decode one symbol from bitstream
      end
    end
  end
end
```

### 4. Data Models

**Purpose**: Represent CAB file structures

**Files**:
- `models/cabinet.rb`
- `models/folder.rb`
- `models/file.rb`

**Design** (Plain Ruby classes):
```ruby
module Cabriolet
  module Models
    class Cabinet
      attr_accessor :filename, :length, :set_id, :set_index, :flags
      attr_accessor :folders, :files, :next_cabinet, :prev_cabinet
      attr_accessor :base_offset, :header_resv, :prevname, :nextname
      attr_accessor :previnfo, :nextinfo

      def initialize
        @folders = []
        @files = []
      end
    end

    class Folder
      attr_accessor :comp_type, :num_blocks, :data_offset
      attr_accessor :next, :data_cab, :merge_prev, :merge_next

      def initialize
        @data_cab = nil
        @merge_prev = nil
        @merge_next = nil
      end
    end

    class File
      attr_accessor :filename, :length, :offset, :folder
      attr_accessor :attribs, :date, :time
      attr_accessor :time_h, :time_m, :time_s
      attr_accessor :date_d, :date_m, :date_y
      attr_accessor :next

      def initialize
        @next = nil
      end
    end
  end
end
```

### 5. Decompressors

**Purpose**: Implement compression algorithms

**Base Class**:
```ruby
module Cabriolet
  module Decompressors
    class Base
      def initialize(io_system, input_handle, output_handle, buffer_size)
        @io_system = io_system
        @input = input_handle
        @output = output_handle
        @buffer_size = buffer_size
      end

      def decompress(bytes)
        # Abstract method - implemented by subclasses
        raise NotImplementedError
      end
    end
  end
end
```

**Subclasses**:

1. **LZSS** (`decompressors/lzss.rb`):
   - Window size: 4096 bytes
   - Used by SZDD, KWAJ formats
   - Simple sliding window compression

2. **MSZIP** (`decompressors/mszip.rb`):
   - Deflate algorithm (RFC 1951)
   - 32KB sliding window
   - Huffman coding + LZ77

3. **LZX** (`decompressors/lzx.rb`):
   - Window sizes: 32KB to 2MB
   - Intel E8 preprocessing
   - Multiple Huffman trees

4. **Quantum** (`decompressors/quantum.rb`):
   - Proprietary format
   - Complex algorithm
   - Huffman coding + sliding window

5. **None** (`decompressors/none.rb`):
   - Simple copy operation
   - No decompression

### Layer 3: Algorithm Layer
**Location**: `lib/cabriolet/{compressors|decompressors}/`

Compression algorithms are implemented as separate, reusable components:

**Compressors** (`lib/cabriolet/compressors/`):
- [`Base`](lib/cabriolet/compressors/base.rb:1): Base class for all compressors
- [`LZSS`](lib/cabriolet/compressors/lzss.rb:1): LZSS compression (4KB window, 3 modes)
- [`MSZIP`](lib/cabriolet/compressors/mszip.rb:1): MSZIP/DEFLATE compression
- [`LZX`](lib/cabriolet/compressors/lzx.rb:1): LZX compression with Intel E8 preprocessing
- [`Quantum`](lib/cabriolet/compressors/quantum.rb:1): Quantum compression with adaptive arithmetic coding

**Decompressors** (`lib/cabriolet/decompressors/`):
- [`Base`](lib/cabriolet/decompressors/base.rb:1): Base class for all decompressors
- [`None`](lib/cabriolet/decompressors/none.rb:1): Uncompressed data handling
- [`LZSS`](lib/cabriolet/decompressors/lzss.rb:1): LZSS decompression
- [`MSZIP`](lib/cabriolet/decompressors/mszip.rb:1): MSZIP/DEFLATE decompression
- [`LZX`](lib/cabriolet/decompressors/lzx.rb:1): LZX decompression
- [`Quantum`](lib/cabriolet/decompressors/quantum.rb:1): Quantum decompression

**AlgorithmFactory** (`lib/cabriolet/algorithm_factory.rb`):
- Centralized registry for algorithm instantiation
- Eliminates hardcoded case statements in format handlers
- Supports custom algorithm registration
- Enables Open/Closed Principle (extend without modifying)

The AlgorithmFactory pattern provides several key benefits:

```ruby
# Global factory with built-in algorithms
Cabriolet.algorithm_factory.compressor(1)  # => LZSS compressor

# Register custom algorithms
factory = Cabriolet::AlgorithmFactory.new
factory.register(:compressor, 99, MyCustomCompressor)

# Per-instance factories for dependency injection
decompressor = Cabriolet::CAB::Decompressor.new(
  "file.cab",
  algorithm_factory: custom_factory
)
```

This allows format handlers to remain unchanged when adding new compression algorithms, following the Open/Closed Principle.

### 6. CAB Format Support

**Parser** (`cab/parser.rb`):
```ruby
module Cabriolet
  module CAB
    class Parser
      def initialize(io_system)
        @io_system = io_system
      end

      def parse(filename)
        # Parse CAB file headers
        # Returns Cabinet model
      end

      private

      def read_header(handle)
        # Read CFHEADER structure
      end

      def read_folders(handle, count)
        # Read CFFOLDER structures
      end

      def read_files(handle, count)
        # Read CFFILE structures
      end
    end
  end
end
```

**Decompressor** (`cab/decompressor.rb`):
```ruby
module Cabriolet
  module CAB
    class Decompressor
      def initialize(io_system = nil)
        @io_system = io_system || System::IOSystem.new
        @parser = Parser.new(@io_system)
      end

      def open(filename)
        # Open and parse CAB file
        @parser.parse(filename)
      end

      def extract(file, output_filename)
        # Extract a single file
      end

      def extract_all(output_directory)
        # Extract all files
      end

      private

      def select_decompressor(comp_type)
        # Select appropriate decompressor
      end
    end
  end
end
```

**Extractor** (`cab/extractor.rb`):
```ruby
module Cabriolet
  module CAB
    class Extractor
      def initialize(cabinet, io_system)
        @cabinet = cabinet
        @io_system = io_system
      end

      def extract_file(file, output_path)
        # Extract single file from cabinet
      end
    end
  end
end
```

### 7. CLI Tool

**Design** (`cli.rb`):
```ruby
require 'thor'

module Cabriolet
  class CLI < Thor
    desc 'list FILE', 'List contents of CAB file'
    def list(file)
      # List all files in cabinet
    end

    desc 'extract FILE [OUTPUT_DIR]', 'Extract CAB file'
    option :verbose, type: :boolean, aliases: '-v'
    def extract(file, output_dir = '.')
      # Extract files
    end

    desc 'info FILE', 'Show CAB file information'
    def info(file)
      # Show detailed cabinet info
    end

    desc 'test FILE', 'Test CAB file integrity'
    def test(file)
      # Test file integrity
    end
  end
end
```

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)

- [x] Project setup (Gemfile, gemspec, RSpec)
- [ ] System abstraction layer
- [ ] Binary I/O utilities
- [ ] Bitstream reader
- [ ] Basic error handling

### Phase 2: Format Support (Weeks 3-4)

- [ ] CAB format constants
- [ ] Data models with Lutaml::Model
- [ ] CAB parser (headers, folders, files)
- [ ] Cabinet search functionality

### Phase 3: Basic Decompression (Weeks 5-6)

- [ ] Base decompressor class
- [ ] None decompressor (uncompressed)
- [ ] LZSS decompressor
- [ ] Basic extraction workflow

### Phase 4: MSZIP Support (Weeks 7-8)

- [ ] Huffman tree builder
- [ ] Huffman decoder
- [ ] MSZIP/Deflate decompressor
- [ ] Integration with CAB extractor

### Phase 5: LZX Support (Weeks 9-11)

- [ ] LZX constants and structures
- [ ] LZX bitstream handling
- [ ] LZX Huffman trees
- [ ] Intel E8 transformation
- [ ] LZX decompressor

### Phase 6: Quantum Support (Weeks 12-13)

- [ ] Quantum algorithm research
- [ ] Quantum decompressor
- [ ] Special case handling

### Phase 7: Testing & Polish (Weeks 14-15)

- [ ] Comprehensive test suite
- [ ] Performance optimization
- [ ] Documentation
- [ ] CLI refinement

### Phase 8: Extended Formats (Future)

- [ ] CHM (HTML Help) format support
- [ ] LIT (eBook) format support
- [ ] HLP (Help) format support

## CAB Format Specification

### File Structure

```
┌──────────────────────────────┐
│     CFHEADER (36+ bytes)     │  Cabinet header
├──────────────────────────────┤
│   Reserved area (optional)   │
├──────────────────────────────┤
│   Previous cabinet name      │  (if flags & 0x01)
├──────────────────────────────┤
│   Next cabinet name          │  (if flags & 0x02)
├──────────────────────────────┤
│   CFFOLDER[1] (8+ bytes)     │  Folder entries
│   CFFOLDER[2]                │
│   ...                        │
├──────────────────────────────┤
│   CFFILE[1] (16+ bytes)      │  File entries
│   CFFILE[2]                  │
│   ...                        │
├──────────────────────────────┤
│   CFDATA[1] (8+ bytes)       │  Data blocks
│   Compressed data[1]         │
│   CFDATA[2]                  │
│   Compressed data[2]         │
│   ...                        │
└──────────────────────────────┘
```

### CFHEADER Structure

```
Offset  Size  Description
------  ----  -----------
0       4     Signature (0x4643534D = "MSCF")
4       4     Reserved
8       4     Cabinet file size
12      4     Reserved
16      4     Files offset
20      4     Reserved
24      1     Minor version
25      1     Major version
26      2     Number of folders
28      2     Number of files
30      2     Flags
32      2     Set ID
34      2     Cabinet index
```

### Compression Types

| Type | Value | Description |
|------|-------|-------------|
| None | 0 | No compression |
| MSZIP | 1 | MSZIP (deflate) |
| Quantum | 2 | Quantum compression |
| LZX | 3 | LZX compression |

## Testing Strategy

### Unit Tests

- Each decompressor tested independently
- Binary I/O utilities tested with known data
- Huffman decoder tested with sample trees
- Parser tested with valid/invalid CAB files

### Integration Tests

- Full extraction of known CAB files
- Multi-cabinet spanning tests
- Error recovery tests
- Performance benchmarks

### Test Data

#### libmspack Test Fixtures

Copy test files from libmspack to `spec/fixtures/libmspack/`:

```bash
# Directory structure
spec/fixtures/libmspack/
├── README.adoc                                    # License acknowledgment
└── cabd/
    ├── normal_2files_1folder.cab                 # Basic CAB
    ├── mszip_lzx_qtm.cab                          # Multiple compression
    ├── multi_basic_pt1.cab                        # Multi-part cabinet
    ├── multi_basic_pt2.cab
    ├── cve-2010-2800-mszip-infinite-loop.cab      # Security test
    └── ...
```

#### Test Coverage Strategy

Each RSpec file tests its corresponding class:
- **Unit Tests**: Test each class in isolation with mocks/stubs
- **Integration Tests**: Test component interactions
- **End-to-End Tests**: Full extraction workflow with real CAB files

**Example RSpec structure**:
```ruby
# spec/decompressors/lzx_spec.rb
RSpec.describe Cabriolet::Decompressors::LZX do
  describe '#initialize' do
    # Test initialization
  end

  describe '#decompress' do
    context 'with valid LZX data' do
      # Test decompression
    end

    context 'with corrupted data' do
      # Test error handling
    end
  end
end
```

## Error Handling

### Error Classes

```ruby
module Cabriolet
  class Error < StandardError; end

  class IOError < Error; end
  class ParseError < Error; end
  class DecompressionError < Error; end
  class ChecksumError < Error; end
  class UnsupportedFormatError < Error; end
end
```

### Error Strategy

1. **Graceful degradation**: Attempt partial extraction on errors
2. **Clear messages**: Provide actionable error information
3. **Salvage mode**: Optional parameter to skip errors and extract what's possible
4. **Validation**: Verify checksums and data integrity

## Performance Considerations

1. **Buffer Sizes**: Default 4KB buffers, configurable
2. **Memory Usage**: Stream-based processing, avoid loading entire files
3. **Lookup Tables**: Pre-computed Huffman decode tables
4. **Ruby Optimization**:
   - Use byte arrays instead of strings where appropriate
   - Minimize object allocation in hot paths
   - Use bitwise operations efficiently

## Documentation

### README.adoc Structure

```asciidoc
= Cabriolet

Pure Ruby implementation of Microsoft CAB file extraction.

== Features

* Full CAB format support
* Multiple compression algorithms
* No C extensions required
* CLI tool included

== Installation

== Usage

=== Library

=== Command Line

== Architecture

== Development

== License
```

### Documentation

See [`DOCUMENTATION_PLAN.md`](DOCUMENTATION_PLAN.md:1) for complete documentation architecture.

**Documentation Structure**:
- `docs/getting-started/` - Installation, quick start, first extraction
- `docs/user-guide/` - Basic usage, advanced usage, CLI/API reference
- `docs/formats/` - CAB format, compression algorithms (MSZIP, LZX, Quantum, LZSS)
- `docs/technical/` - Architecture, system abstraction, binary I/O, Huffman coding
- `docs/developer/` - Contributing, code style, testing, extending
- `docs/appendix/` - Glossary, CAB spec, troubleshooting, FAQ

**Standard Document Format**:
Every document follows: Purpose → References → Concepts → Body → Bibliography

**Cross-Cutting Documentation**:
- Common options shared between CLI and API documented once
- Each compression format gets detailed explanation
- Progressive disclosure: basic → intermediate → advanced

## Dependencies

### Runtime

- `bindata` (~> 2.5) - For binary data structures
- `thor` (~> 1.3) - For CLI

### Development

- `rspec` - Testing framework
- `rake` - Build tool
- `rubocop` - Code style
- `yard` - Documentation

## Licensing

### Cabriolet License

**BSD 3-Clause License**

The Cabriolet gem itself is released under the BSD 3-Clause License, allowing:
- Commercial use
- Modification
- Distribution
- Private use

With conditions:
- License and copyright notice must be included
- No liability or warranty

### Test Fixtures License

The test fixtures in `spec/fixtures/libmspack/` are from the libmspack project and remain under the **LGPL 2.1** license. These are used solely for testing and validation purposes and are not distributed as part of the gem's runtime code.

A `spec/fixtures/libmspack/README.adoc` file will acknowledge:
- Copyright by Stuart Caie and libmspack contributors
- LGPL 2.1 licensing of test files
- Gratitude to the libmspack project for excellent test coverage

### Implementation Notes

This is a clean-room implementation based on:
1. Public CAB file format specifications (Microsoft documentation)
2. Algorithm specifications (LZX, deflate/RFC 1951, etc.)
3. Test-driven development using publicly available test files

The implementation does not copy code from libmspack but reimplements the algorithms in Ruby based on specifications and format documentation.

## Success Criteria

1. Successfully extract all test CAB files from libmspack test suite
2. Handle all compression methods (MSZIP, LZX, Quantum, LZSS, None)
3. Support multi-part cabinet sets
4. Achieve reasonable performance (within 3-5x of native C implementation)
5. Zero C extension dependencies
6. Comprehensive test coverage (>90%)
7. Well-documented API and CLI