# Cabriolet Plugin Example

A reference implementation demonstrating how to create plugins for Cabriolet,
the pure Ruby Microsoft compression format library.

## Overview

This plugin provides a simple ROT13 "compression" algorithm to demonstrate all
aspects of Cabriolet's plugin architecture. ROT13 doesn't actually compress data
— it rotates each letter by 13 positions in the alphabet — but it serves as an
excellent learning tool because:

- The algorithm is simple and easy to understand
- It demonstrates both compression and decompression
- It's symmetric (compressing twice returns the original)
- The code is easy to follow and well-documented

## Features Demonstrated

This example plugin showcases:

- ✅ **Plugin metadata definition** - All required and optional metadata fields
- ✅ **Algorithm registration** - Both compressor and decompressor
- ✅ **Lifecycle hooks** - Activate, deactivate, and cleanup
- ✅ **Dependency handling** - How to specify dependencies
- ✅ **Configuration options** - Plugin-specific settings
- ✅ **Full YARD documentation** - API documentation best practices
- ✅ **Comprehensive tests** - Testing strategies for plugins
- ✅ **Error handling** - Proper exception management

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cabriolet-plugin-example'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install cabriolet-plugin-example
```

## Usage

### Loading the Plugin

```ruby
require 'cabriolet'
require 'cabriolet/plugins/example'

# Access the plugin manager
manager = Cabriolet.plugin_manager

# Discover available plugins
manager.discover_plugins

# Load the example plugin
manager.load_plugin("cabriolet-plugin-example")

# Activate the plugin
manager.activate_plugin("cabriolet-plugin-example")
```

### Using ROT13 Compression

```ruby
# Create I/O system
io = Cabriolet::System::IOSystem.new

# Open input and output
input = io.open_file("message.txt", "rb")
output = io.open_file("message.rot13", "wb")

# Get the algorithm factory
factory = Cabriolet.algorithm_factory

# Create ROT13 compressor
compressor = factory.create(:rot13, :compressor, io, input, output, 4096)

# Compress the data
bytes = compressor.compress
puts "Compressed #{bytes} bytes"
```

### Using ROT13 Decompression

```ruby
# Open compressed file and output
input = io.open_file("message.rot13", "rb")
output = io.open_file("message.txt", "wb")

# Create ROT13 decompressor
decompressor = factory.create(:rot13, :decompressor, io, input, output, 4096)

# Decompress the data
bytes = decompressor.decompress(File.size("message.rot13"))
puts "Decompressed #{bytes} bytes"
```

## Creating Your Own Plugin

This example serves as a template for creating your own Cabriolet plugins.
Follow this guide to develop custom compression algorithms or format handlers.

### Step 1: Plugin Structure

Create the following directory structure:

```
your-plugin/
├── lib/
│   └── cabriolet/
│       └── plugins/
│           └── your_plugin.rb
├── spec/
│   └── your_plugin_spec.rb
├── your-plugin.gemspec
├── Gemfile
├── Rakefile
└── README.md
```

### Step 2: Inherit from Plugin Base Class

```ruby
module Cabriolet
  module Plugins
    class YourPlugin < Plugin
      def metadata
        {
          name: "your-plugin",
          version: "1.0.0",
          author: "Your Name",
          description: "Plugin description",
          cabriolet_version: "~> 0.1",
          # ... other metadata
        }
      end

      def setup
        # Register your algorithms here
        register_algorithm(:your_algo, YourCompressor,
                          category: :compressor)
        register_algorithm(:your_algo, YourDecompressor,
                          category: :decompressor)
      end
    end
  end
end
```

### Step 3: Implement Algorithms

#### Compressor

```ruby
class YourCompressor < Cabriolet::Compressors::Base
  def compress
    # Read from @input
    # Process data
    # Write to @output
    # Return bytes written
  end
end
```

#### Decompressor

```ruby
class YourDecompressor < Cabriolet::Decompressors::Base
  def decompress(bytes)
    # Read from @input
    # Process data
    # Write to @output
    # Return bytes decompressed
  end

  def free
    # Clean up resources
  end
end
```

### Step 4: Required Metadata Fields

All plugins must provide these metadata fields:

- **name**: Plugin identifier (lowercase, hyphens/underscores only)
- **version**: Semantic version (e.g., "1.0.0")
- **author**: Author name or organization
- **description**: Brief description of plugin functionality
- **cabriolet_version**: Compatible Cabriolet version (e.g., "~> 0.1")

### Step 5: Optional Metadata Fields

Enhance your plugin with optional metadata:

- **homepage**: Plugin homepage URL
- **license**: License identifier (e.g., "MIT", "BSD-2-Clause")
- **dependencies**: Array of plugin dependencies
- **tags**: Array of search tags
- **provides**: Hash of capabilities (algorithms, formats)

### Step 6: Lifecycle Hooks

Implement lifecycle hooks for plugin management:

```ruby
def activate
  # Called when plugin is activated
  # Initialize resources, start services, etc.
end

def deactivate
  # Called when plugin is deactivated
  # Pause services, release resources, etc.
end

def cleanup
  # Called when plugin is unloaded
  # Final cleanup, close connections, etc.
end
```

### Step 7: Write Tests

Create comprehensive tests for your plugin:

```ruby
RSpec.describe YourPlugin do
  describe "#metadata" do
    it "returns valid metadata" do
      # Test metadata
    end
  end

  describe "#setup" do
    it "registers algorithms" do
      # Test registration
    end
  end

  describe "YourCompressor" do
    it "compresses data correctly" do
      # Test compression
    end
  end

  describe "YourDecompressor" do
    it "decompresses data correctly" do
      # Test decompression
    end
  end
end
```

### Step 8: Document Your Code

Use YARD documentation for all public methods:

```ruby
# Brief description
#
# Detailed description of the method's purpose and behavior.
#
# @param param1 [Type] Description of param1
# @param param2 [Type] Description of param2
# @return [Type] Description of return value
#
# @example
#   result = method(arg1, arg2)
#   puts result
def your_method(param1, param2)
  # Implementation
end
```

## API Documentation

### Plugin Base Class

Inherit from `Cabriolet::Plugin` and implement:

- `metadata()` - Returns plugin metadata hash
- `setup()` - Registers algorithms and formats
- `activate()` - Optional lifecycle hook
- `deactivate()` - Optional lifecycle hook
- `cleanup()` - Optional lifecycle hook

### Algorithm Base Classes

Inherit from:

- `Cabriolet::Compressors::Base` for compressors
- `Cabriolet::Decompressors::Base` for decompressors

Required methods:

- Compressor: `compress()` - Returns bytes written
- Decompressor: `decompress(bytes)` - Returns bytes decompressed
- Decompressor: `free()` - Optional resource cleanup

### Registration Methods

Available in plugin `setup()` method:

```ruby
register_algorithm(type, klass, category:, priority: 0, format: nil)
register_format(format, handler)
```

## Testing

Run the test suite:

```bash
bundle exec rspec
```

Run with coverage:

```bash
COVERAGE=true bundle exec rspec
```

## Best Practices

### Do:

- ✅ Provide comprehensive metadata
- ✅ Document all public methods with YARD
- ✅ Write thorough tests for all functionality
- ✅ Handle errors gracefully
- ✅ Follow Ruby style guidelines
- ✅ Use semantic versioning
- ✅ Validate input parameters
- ✅ Clean up resources in `free()`

### Don't:

- ❌ Modify global state without cleanup
- ❌ Use dangerous methods (eval, system, etc.)
- ❌ Depend on external binaries
- ❌ Leave resources unclosed
- ❌ Raise exceptions in lifecycle hooks
- ❌ Assume specific execution order
- ❌ Store state in class variables

## Security Considerations

When developing plugins:

1. **Avoid dangerous methods**: Don't use `eval`, `system`, `exec`, etc.
2. **Validate input**: Check parameters before processing
3. **Handle untrusted data carefully**: Assume input may be malicious
4. **Limit resource usage**: Implement reasonable limits
5. **Clean up properly**: Always release resources
6. **Follow principle of least privilege**: Request minimum permissions

Cabriolet's plugin validator will warn about potentially dangerous code patterns.

## Contributing

This is a reference implementation. To contribute improvements:

1. Fork the repository
2. Create your feature branch
3. Write tests for your changes
4. Ensure all tests pass
5. Submit a pull request

## License

BSD-2-Clause - see LICENSE file for details

## Related Resources

- [Cabriolet Main Repository](https://github.com/omnizip/cabriolet)
- [Plugin Architecture Documentation](https://github.com/omnizip/cabriolet/blob/main/docs/PLUGINS.md)
- [API Documentation](https://rubydoc.info/gems/cabriolet)

## Questions?

- Open an issue on GitHub
- Check the documentation
- Review this example code
- Examine the test suite

This plugin is designed to help you create your own Cabriolet plugins.
Happy coding! 🎉