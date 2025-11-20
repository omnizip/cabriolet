# Cabriolet BZip2 Plugin

An advanced example plugin for Cabriolet demonstrating BZip2 compression algorithm integration with configuration, error handling, and progress reporting.

## Overview

This plugin showcases advanced plugin development patterns including:

- **Configuration Management**: Block size and compression level settings
- **Error Handling**: Comprehensive validation and error recovery
- **Progress Reporting**: Real-time compression/decompression progress
- **Format-Specific Registration**: BZ2 format handler integration
- **Statistics Tracking**: Compression ratio and performance metrics
- **Resource Management**: Proper cleanup and state management

**Note**: This is a stub implementation for demonstration purposes. A production BZip2 plugin would require the full BZip2 algorithm implementation.

## Features

### Configuration Options

The plugin supports BZip2-specific compression parameters:

- **Block Size** (1-9): Controls memory usage and compression ratio
  - 1 = 100KB blocks (fast, less compression)
  - 9 = 900KB blocks (slower, better compression)
  - Default: 9

- **Compression Level** (1-9): Balances speed vs compression
  - 1 = Fast compression (less compression)
  - 9 = Best compression (slower)
  - Default: 9

### Advanced Features

- ✅ **Header Validation**: Validates BZip2 magic bytes and version
- ✅ **Progress Callbacks**: Monitor compression/decompression progress
- ✅ **Error Detection**: Comprehensive error checking and reporting
- ✅ **Statistics**: Track compression ratios and performance
- ✅ **Resource Cleanup**: Proper resource management
- ✅ **State Validation**: Ensures valid operational state

## Installation

Add to your Gemfile:

```ruby
gem 'cabriolet-plugin-bzip2'
```

Or install directly:

```bash
gem install cabriolet-plugin-bzip2
```

## Usage

### Basic Usage

```ruby
require 'cabriolet'
require 'cabriolet/plugins/bzip2'

# Load and activate plugin
manager = Cabriolet.plugin_manager
manager.load_plugin("cabriolet-plugin-bzip2")
manager.activate_plugin("cabriolet-plugin-bzip2")

# Use BZip2 compression
io = Cabriolet::System::IOSystem.new
input = io.open_file("data.txt", "rb")
output = io.open_file("data.bz2", "wb")

factory = Cabriolet.algorithm_factory
compressor = factory.create(:bzip2, :compressor, io, input, output, 4096)
bytes = compressor.compress

puts "Compressed #{bytes} bytes"
```

### Configuration

#### Via Environment Variables

```bash
export BZIP2_BLOCK_SIZE=9
export BZIP2_LEVEL=9
```

#### Via Constructor Options

```ruby
compressor = factory.create(:bzip2, :compressor,
                            io, input, output, 4096,
                            block_size: 5,
                            level: 7)
```

### Progress Reporting

```ruby
# Define progress callback
progress_callback = lambda do |percentage|
  puts "Progress: #{percentage}%"
end

# Create compressor with progress reporting
compressor = factory.create(:bzip2, :compressor,
                            io, input, output, 4096,
                            progress: progress_callback)
compressor.compress
```

### Decompression

```ruby
# Open compressed file
input = io.open_file("data.bz2", "rb")
output = io.open_file("data.txt", "wb")

# Create decompressor
decompressor = factory.create(:bzip2, :decompressor,
                              io, input, output, 4096)

# Decompress with progress
decompressor = factory.create(:bzip2, :decompressor,
                              io, input, output, 4096,
                              progress: lambda { |pct| puts "#{pct}%" })
bytes = decompressor.decompress(File.size("data.bz2"))
```

## Advanced Concepts Demonstrated

### 1. Configuration Management

The plugin demonstrates proper configuration loading and validation:

```ruby
def load_configuration
  {
    block_size: ENV.fetch("BZIP2_BLOCK_SIZE", DEFAULT_BLOCK_SIZE).to_i,
    level: ENV.fetch("BZIP2_LEVEL", DEFAULT_LEVEL).to_i,
  }
end

def validate_configuration
  unless (MIN_BLOCK_SIZE..MAX_BLOCK_SIZE).cover?(@config[:block_size])
    raise PluginError, "Invalid block_size"
  end
end
```

### 2. State Validation

Proper state checking before operations:

```ruby
def validate_state!
  raise CompressionError, "Input closed" if @input.closed?
  raise CompressionError, "Output closed" if @output.closed?
end
```

### 3. Header Handling

BZip2 header parsing and validation:

```ruby
def read_and_validate_header
  header = @input.read(4)
  raise DecompressionError, "Truncated" if header.size < 4

  magic = header[0, 2]
  raise DecompressionError, "Invalid magic" unless magic == "BZ"

  version = header[2]
  raise DecompressionError, "Unsupported version" unless version == "h"

  @block_size = header[3].to_i
end
```

### 4. Progress Reporting

Callback-based progress reporting:

```ruby
def report_progress(current, total)
  return if total.zero?
  percentage = ((current.to_f / total) * 100).round(2)
  @progress.call(percentage)
end
```

### 5. Statistics Tracking

Performance metrics collection:

```ruby
def report_statistics
  ratio = ((@stats[:bytes_out].to_f / @stats[:bytes_in]) * 100).round(2)
  puts "Compression ratio: #{ratio}%"
end
```

## Error Handling

The plugin demonstrates comprehensive error handling:

### Compression Errors

```ruby
begin
  compressor.compress
rescue Cabriolet::CompressionError => e
  puts "Compression failed: #{e.message}"
end
```

### Decompression Errors

```ruby
begin
  decompressor.decompress(size)
rescue Cabriolet::DecompressionError => e
  puts "Decompression failed: #{e.message}"
  # Invalid header, unsupported version, etc.
end
```

### Configuration Errors

```ruby
begin
  plugin.activate
rescue Cabriolet::PluginError => e
  puts "Plugin activation failed: #{e.message}"
  # Invalid block_size, invalid level, etc.
end
```

## Testing

Run the test suite:

```bash
bundle exec rspec
```

The plugin includes comprehensive tests:

- Configuration validation
- Header parsing
- Progress reporting
- Error handling
- State management
- Resource cleanup

## Plugin Development Patterns

This plugin demonstrates several advanced patterns:

### 1. Priority Registration

```ruby
register_algorithm(:bzip2, BZip2Compressor,
                  category: :compressor,
                  priority: 10)  # Higher priority
```

### 2. Format Association

```ruby
provides: {
  algorithms: [:bzip2],
  formats: [:bz2]
}
```

### 3. Lifecycle Management

```ruby
def activate
  validate_configuration
  @activated_at = Time.now
  @compression_stats = { files: 0, bytes_in: 0, bytes_out: 0 }
end

def deactivate
  report_statistics
  @activated_at = nil
end

def cleanup
  @config = nil
  @compression_stats = nil
end
```

### 4. Constructor Options

```ruby
def initialize(io_system, input, output, buffer_size, **kwargs)
  super
  @block_size = kwargs.fetch(:block_size, DEFAULT_BLOCK_SIZE)
  @level = kwargs.fetch(:level, DEFAULT_LEVEL)
  @progress = kwargs[:progress]
  validate_options!
end
```

## Best Practices Demonstrated

1. **Validation First**: Validate all inputs before processing
2. **Clear Errors**: Provide descriptive error messages
3. **Resource Safety**: Always clean up resources
4. **State Management**: Track and validate operational state
5. **Progress Feedback**: Keep users informed of long operations
6. **Configuration Flexibility**: Support multiple configuration sources
7. **Comprehensive Testing**: Test all code paths and error conditions
8. **Documentation**: Document all public APIs and options

## Performance Considerations

### Block Size Selection

- Larger blocks (8-9): Better compression, more memory
- Smaller blocks (1-4): Faster, less memory
- Default (9): Best compression for most cases

### Compression Level

- Level 1-3: Fast compression, lower ratios
- Level 4-6: Balanced speed/compression
- Level 7-9: Best compression, slower

### Progress Reporting

Progress callbacks add minimal overhead:

```ruby
# Efficient progress reporting
def report_progress(current, total)
  return if total.zero?
  percentage = ((current.to_f / total) * 100).round(2)
  @progress.call(percentage) if percentage != @last_percentage
  @last_percentage = percentage
end
```

## Security Considerations

The plugin demonstrates secure practices:

1. **Input Validation**: All inputs are validated
2. **Bounds Checking**: Array/buffer access is bounds-checked
3. **Error Handling**: Errors don't leak sensitive information
4. **Resource Limits**: Configuration limits prevent abuse
5. **Safe Defaults**: Conservative default settings

## Contributing

This plugin serves as a reference for creating production plugins. To improve it:

1. Implement full BZip2 algorithm
2. Add streaming support
3. Optimize performance
4. Enhance error messages
5. Add more configuration options

## License

BSD-2-Clause

## Related Resources

- [Simple Plugin Example (ROT13)](../cabriolet-plugin-example/)
- [Cabriolet Documentation](https://github.com/omnizip/cabriolet)
- [Plugin Development Guide](../../README.md)

## Questions?

- Review the simple plugin example first
- Check comprehensive tests in `spec/`
- Read inline documentation
- Open an issue on GitHub

This plugin demonstrates production-ready patterns for Cabriolet plugin development! 🚀