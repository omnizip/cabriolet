# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cabriolet::PluginManager do
  # Test plugin classes
  class TestPlugin1 < Cabriolet::Plugin
    def metadata
      {
        name: "test-plugin-1",
        version: "1.0.0",
        author: "Test Author",
        description: "First test plugin",
        cabriolet_version: "~> 0.1",
      }
    end

    def setup
      # Test setup
    end
  end

  class TestPlugin2 < Cabriolet::Plugin
    def metadata
      {
        name: "test-plugin-2",
        version: "2.0.0",
        author: "Test Author",
        description: "Second test plugin",
        cabriolet_version: ">= 0.1.0",
        dependencies: ["test-plugin-1 >= 1.0"],
      }
    end

    def setup
      # Test setup
    end
  end

  class FailingPlugin < Cabriolet::Plugin
    def metadata
      {
        name: "failing-plugin",
        version: "1.0.0",
        author: "Test Author",
        description: "A plugin that fails",
        cabriolet_version: "~> 0.1",
      }
    end

    def setup
      raise "Setup failed"
    end
  end

  let(:manager) { described_class.instance }

  before do
    # Clear plugin registry before each test
    manager.instance_variable_set(:@plugins, {})
    manager.instance_variable_set(:@formats, {})
  end

  describe "singleton pattern" do
    it "returns the same instance" do
      instance1 = described_class.instance
      instance2 = described_class.instance
      expect(instance1).to be(instance2)
    end

    it "is a singleton" do
      expect(described_class).to include(Singleton)
    end
  end

  describe "#initialize" do
    it "initializes with empty registries" do
      new_manager = described_class.instance
      # Reset to ensure clean state
      new_manager.instance_variable_set(:@plugins, {})
      new_manager.instance_variable_set(:@formats, {})

      expect(new_manager.plugins).to eq({})
      expect(new_manager.formats).to eq({})
    end
  end

  describe "#register" do
    it "registers a valid plugin" do
      plugin = TestPlugin1.new(manager)
      expect(manager.register(plugin)).to be true
      expect(manager.plugins).to have_key("test-plugin-1")
    end

    it "stores plugin metadata" do
      plugin = TestPlugin1.new(manager)
      manager.register(plugin)

      entry = manager.plugins["test-plugin-1"]
      expect(entry[:metadata][:name]).to eq("test-plugin-1")
      expect(entry[:metadata][:version]).to eq("1.0.0")
      expect(entry[:state]).to eq(:discovered)
    end

    it "rejects non-plugin objects" do
      expect do
        manager.register(Object.new)
      end.to raise_error(Cabriolet::PluginError,
                         /must inherit from/)
    end

    it "rejects duplicate plugin names" do
      plugin1 = TestPlugin1.new(manager)
      plugin2 = TestPlugin1.new(manager)

      manager.register(plugin1)
      expect do
        manager.register(plugin2)
      end.to raise_error(Cabriolet::PluginError, /already registered/)
    end

    it "validates plugin before registration" do
      invalid_plugin_class = Class.new do
        def metadata
          { name: "invalid" }
        end
      end

      plugin = invalid_plugin_class.new
      expect do
        manager.register(plugin)
      end.to raise_error(Cabriolet::PluginError, /must inherit/)
    end
  end

  describe "#load_plugin" do
    before do
      plugin = TestPlugin1.new(manager)
      manager.register(plugin)
    end

    it "loads a discovered plugin" do
      expect(manager.load_plugin("test-plugin-1")).to be true
      entry = manager.plugins["test-plugin-1"]
      expect(entry[:state]).to eq(:loaded)
    end

    it "calls plugin's setup method" do
      plugin = manager.plugins["test-plugin-1"][:instance]
      expect(plugin).to receive(:setup)
      manager.load_plugin("test-plugin-1")
    end

    it "raises error for non-existent plugin" do
      expect do
        manager.load_plugin("non-existent")
      end.to raise_error(Cabriolet::PluginError, /not found/)
    end

    it "handles plugin setup failures" do
      failing_plugin = FailingPlugin.new(manager)
      manager.register(failing_plugin)

      expect do
        manager.load_plugin("failing-plugin")
      end.to raise_error(Cabriolet::PluginError, /Failed to load/)

      entry = manager.plugins["failing-plugin"]
      expect(entry[:state]).to eq(:failed)
      expect(entry[:error]).to include("Setup failed")
    end

    it "returns true if already loaded" do
      manager.load_plugin("test-plugin-1")
      expect(manager.load_plugin("test-plugin-1")).to be true
    end

    it "checks dependencies before loading" do
      plugin2 = TestPlugin2.new(manager)
      manager.register(plugin2)

      # Should succeed since test-plugin-1 is already registered
      manager.load_plugin("test-plugin-1")
      expect(manager.load_plugin("test-plugin-2")).to be true
    end
  end

  describe "#activate_plugin" do
    before do
      plugin = TestPlugin1.new(manager)
      manager.register(plugin)
      manager.load_plugin("test-plugin-1")
    end

    it "activates a loaded plugin" do
      expect(manager.activate_plugin("test-plugin-1")).to be true
      entry = manager.plugins["test-plugin-1"]
      expect(entry[:state]).to eq(:active)
    end

    it "calls plugin's activate method" do
      plugin = manager.plugins["test-plugin-1"][:instance]
      expect(plugin).to receive(:activate)
      manager.activate_plugin("test-plugin-1")
    end

    it "raises error for non-existent plugin" do
      expect do
        manager.activate_plugin("non-existent")
      end.to raise_error(Cabriolet::PluginError, /not found/)
    end

    it "raises error if plugin not loaded" do
      plugin2 = TestPlugin2.new(manager)
      manager.register(plugin2)

      expect do
        manager.activate_plugin("test-plugin-2")
      end.to raise_error(Cabriolet::PluginError, /must be loaded/)
    end

    it "returns true if already active" do
      manager.activate_plugin("test-plugin-1")
      expect(manager.activate_plugin("test-plugin-1")).to be true
    end
  end

  describe "#deactivate_plugin" do
    before do
      plugin = TestPlugin1.new(manager)
      manager.register(plugin)
      manager.load_plugin("test-plugin-1")
      manager.activate_plugin("test-plugin-1")
    end

    it "deactivates an active plugin" do
      expect(manager.deactivate_plugin("test-plugin-1")).to be true
      entry = manager.plugins["test-plugin-1"]
      expect(entry[:state]).to eq(:loaded)
    end

    it "calls plugin's deactivate method" do
      plugin = manager.plugins["test-plugin-1"][:instance]
      expect(plugin).to receive(:deactivate)
      manager.deactivate_plugin("test-plugin-1")
    end

    it "raises error for non-existent plugin" do
      expect do
        manager.deactivate_plugin("non-existent")
      end.to raise_error(Cabriolet::PluginError, /not found/)
    end

    it "returns true if not active" do
      manager.deactivate_plugin("test-plugin-1")
      expect(manager.deactivate_plugin("test-plugin-1")).to be true
    end
  end

  describe "#list_plugins" do
    before do
      plugin1 = TestPlugin1.new(manager)
      plugin2 = TestPlugin2.new(manager)
      manager.register(plugin1)
      manager.register(plugin2)
      manager.load_plugin("test-plugin-1")
      manager.activate_plugin("test-plugin-1")
    end

    it "lists all plugins without filter" do
      list = manager.list_plugins
      expect(list).to have_key("test-plugin-1")
      expect(list).to have_key("test-plugin-2")
    end

    it "includes plugin metadata and state" do
      list = manager.list_plugins
      plugin_info = list["test-plugin-1"]

      expect(plugin_info[:metadata][:name]).to eq("test-plugin-1")
      expect(plugin_info[:state]).to eq(:active)
    end

    it "filters plugins by state" do
      list = manager.list_plugins(state: :active)
      expect(list).to have_key("test-plugin-1")
      expect(list).not_to have_key("test-plugin-2")
    end

    it "returns empty hash when no plugins match filter" do
      list = manager.list_plugins(state: :failed)
      expect(list).to be_empty
    end
  end

  describe "#plugin" do
    before do
      plugin = TestPlugin1.new(manager)
      manager.register(plugin)
    end

    it "returns plugin instance by name" do
      plugin = manager.plugin("test-plugin-1")
      expect(plugin).to be_a(TestPlugin1)
    end

    it "returns nil for non-existent plugin" do
      expect(manager.plugin("non-existent")).to be_nil
    end
  end

  describe "#plugin_active?" do
    before do
      plugin = TestPlugin1.new(manager)
      manager.register(plugin)
    end

    it "returns false for discovered plugin" do
      expect(manager.plugin_active?("test-plugin-1")).to be false
    end

    it "returns false for loaded plugin" do
      manager.load_plugin("test-plugin-1")
      expect(manager.plugin_active?("test-plugin-1")).to be false
    end

    it "returns true for active plugin" do
      manager.load_plugin("test-plugin-1")
      manager.activate_plugin("test-plugin-1")
      expect(manager.plugin_active?("test-plugin-1")).to be true
    end

    it "returns false for non-existent plugin" do
      expect(manager.plugin_active?("non-existent")).to be false
    end
  end

  describe "#register_format" do
    it "registers a format handler" do
      handler = Class.new
      manager.register_format(:test, handler)
      expect(manager.formats[:test]).to eq(handler)
    end
  end

  describe "#format_handler" do
    it "returns registered handler" do
      handler = Class.new
      manager.register_format(:test, handler)
      expect(manager.format_handler(:test)).to eq(handler)
    end

    it "returns nil for unregistered format" do
      expect(manager.format_handler(:unknown)).to be_nil
    end
  end

  describe "thread safety" do
    it "uses mutex for thread-safe operations" do
      mutex = manager.instance_variable_get(:@mutex)
      expect(mutex).to be_a(Mutex)
    end
  end

  describe "error isolation" do
    it "isolates plugin errors from manager" do
      failing = FailingPlugin.new(manager)
      manager.register(failing)

      # Manager should not crash
      expect do
        manager.load_plugin("failing-plugin")
      end.to raise_error(Cabriolet::PluginError)

      # Manager should still be functional
      plugin = TestPlugin1.new(manager)
      expect { manager.register(plugin) }.not_to raise_error
    end

    it "marks failed plugins appropriately" do
      failing = FailingPlugin.new(manager)
      manager.register(failing)

      begin
        manager.load_plugin("failing-plugin")
      rescue Cabriolet::PluginError
        # Expected
      end

      entry = manager.plugins["failing-plugin"]
      expect(entry[:state]).to eq(:failed)
      expect(entry[:error]).not_to be_nil
    end
  end

  describe "#discover_plugins" do
    it "searches for plugin files" do
      expect(Gem).to receive(:find_files)
        .with("cabriolet/plugins/**/*.rb")
        .and_return([])

      manager.discover_plugins
    end

    it "returns list of discovered plugin names" do
      allow(Gem).to receive(:find_files).and_return([])
      result = manager.discover_plugins
      expect(result).to be_an(Array)
    end
  end
end
