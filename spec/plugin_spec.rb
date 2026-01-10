# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::Plugin do
  # Test plugin class
  class TestPlugin < Cabriolet::Plugin
    def metadata
      {
        name: "test-plugin",
        version: "1.0.0",
        author: "Test Author",
        description: "A test plugin",
        cabriolet_version: "~> 0.1",
      }
    end

    def setup
      # Test setup
    end
  end

  # Plugin with extended metadata
  class ExtendedPlugin < Cabriolet::Plugin
    def metadata
      {
        name: "extended-plugin",
        version: "2.0.0",
        author: "Extended Author",
        description: "An extended test plugin",
        cabriolet_version: ">= 0.1.0",
        homepage: "https://example.com",
        license: "MIT",
        dependencies: ["other-plugin >= 1.0"],
        tags: ["compression", "test"],
        provides: { algorithms: [:custom], formats: [:special] },
      }
    end

    def setup
      # Extended setup
    end
  end

  describe "#initialize" do
    it "creates a plugin with discovered state" do
      plugin = TestPlugin.new
      expect(plugin.state).to eq(:discovered)
    end

    it "accepts a manager parameter" do
      manager = double("manager")
      plugin = TestPlugin.new(manager)
      expect(plugin.instance_variable_get(:@manager)).to eq(manager)
    end
  end

  describe "#metadata" do
    it "raises NotImplementedError for base class" do
      plugin = Cabriolet::Plugin.new
      expect { plugin.metadata }.to raise_error(NotImplementedError)
    end

    it "returns metadata hash for subclass" do
      plugin = TestPlugin.new
      meta = plugin.metadata

      expect(meta).to be_a(Hash)
      expect(meta[:name]).to eq("test-plugin")
      expect(meta[:version]).to eq("1.0.0")
      expect(meta[:author]).to eq("Test Author")
      expect(meta[:description]).to eq("A test plugin")
      expect(meta[:cabriolet_version]).to eq("~> 0.1")
    end

    it "supports extended metadata" do
      plugin = ExtendedPlugin.new
      meta = plugin.metadata

      expect(meta[:homepage]).to eq("https://example.com")
      expect(meta[:license]).to eq("MIT")
      expect(meta[:dependencies]).to eq(["other-plugin >= 1.0"])
      expect(meta[:tags]).to eq(["compression", "test"])
      expect(meta[:provides]).to eq({ algorithms: [:custom],
                                      formats: [:special] })
    end
  end

  describe "#setup" do
    it "raises NotImplementedError for base class" do
      plugin = Cabriolet::Plugin.new
      expect { plugin.setup }.to raise_error(NotImplementedError)
    end

    it "can be implemented by subclass" do
      plugin = TestPlugin.new
      expect { plugin.setup }.not_to raise_error
    end
  end

  describe "lifecycle hooks" do
    let(:plugin) { TestPlugin.new }

    describe "#activate" do
      it "has default implementation that does nothing" do
        expect { plugin.activate }.not_to raise_error
      end

      it "can be overridden by subclass" do
        custom_plugin_class = Class.new(Cabriolet::Plugin) do
          def metadata
            {
              name: "custom",
              version: "1.0.0",
              author: "Author",
              description: "Description",
              cabriolet_version: "~> 0.1",
            }
          end

          def setup; end

          def activate
            @activated = true
          end
        end

        plugin = custom_plugin_class.new
        plugin.activate
        expect(plugin.instance_variable_get(:@activated)).to be true
      end
    end

    describe "#deactivate" do
      it "has default implementation that does nothing" do
        expect { plugin.deactivate }.not_to raise_error
      end
    end

    describe "#cleanup" do
      it "has default implementation that does nothing" do
        expect { plugin.cleanup }.not_to raise_error
      end
    end
  end

  describe "state management" do
    let(:plugin) { TestPlugin.new }

    describe "#state" do
      it "returns current state" do
        expect(plugin.state).to eq(:discovered)
      end
    end

    describe "#update_state" do
      it "updates plugin state" do
        plugin.send(:update_state, :loaded)
        expect(plugin.state).to eq(:loaded)
      end

      it "accepts valid states" do
        Cabriolet::Plugin::STATES.each do |state|
          expect { plugin.send(:update_state, state) }.not_to raise_error
        end
      end

      it "raises error for invalid state" do
        expect do
          plugin.send(:update_state, :invalid)
        end.to raise_error(ArgumentError, /Invalid state/)
      end
    end
  end

  describe "helper methods" do
    let(:manager) { Cabriolet::PluginManager.instance }
    let(:plugin) { TestPlugin.new(manager) }

    before do
      # Clear manager state
      manager.instance_variable_set(:@plugins, {})
    end

    describe "#register_algorithm" do
      it "raises error without manager" do
        plugin_no_manager = TestPlugin.new(nil)
        expect do
          plugin_no_manager.send(:register_algorithm, :test, Object,
                                 category: :compressor)
        end.to raise_error(Cabriolet::PluginError,
                          /Plugin manager not available/)
      end

      it "registers algorithm with manager" do
        # Create a mock algorithm class
        algo_class = Class.new(Cabriolet::Compressors::Base)

        expect(Cabriolet.algorithm_factory).to receive(:register)
          .with(:test, algo_class, category: :compressor)

        plugin.send(:register_algorithm, :test, algo_class,
                   category: :compressor)
      end

      it "supports priority option" do
        algo_class = Class.new(Cabriolet::Compressors::Base)

        expect(Cabriolet.algorithm_factory).to receive(:register)
          .with(:test, algo_class, category: :compressor, priority: 10)

        plugin.send(:register_algorithm, :test, algo_class,
                   category: :compressor, priority: 10)
      end
    end

    describe "#register_format" do
      it "raises error without manager" do
        plugin_no_manager = TestPlugin.new(nil)
        expect do
          plugin_no_manager.send(:register_format, :test, Object)
        end.to raise_error(Cabriolet::PluginError,
                          /Plugin manager not available/)
      end

      it "registers format with manager" do
        handler_class = Class.new

        expect(manager).to receive(:register_format)
          .with(:test, handler_class)

        plugin.send(:register_format, :test, handler_class)
      end
    end
  end

  describe "constants" do
    it "defines valid plugin states" do
      expect(Cabriolet::Plugin::STATES).to eq(
        %i[discovered loaded active failed disabled]
      )
    end
  end
end
