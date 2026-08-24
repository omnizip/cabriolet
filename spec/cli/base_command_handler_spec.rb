# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require_relative "../support/fixtures"
require_relative "../support/stdout_capture"

# The abstract half of the Template Method: #list, #info and #test are
# implemented in the base class and delegate to hooks a subclass must supply.
# These specs pin what happens when it supplies none, because that error is the
# only guidance a future format author gets.
RSpec.describe Cabriolet::Commands::BaseCommandHandler do
  include StdoutCapture

  # Held in its own let so the example keeps a reference for its whole
  # lifetime. Returning only the path lets the Tempfile be collected, and its
  # finalizer unlinks the file underneath the assertions.
  let(:tempfile) do
    file = Tempfile.new(["bare", ".bin"])
    file.write("payload")
    file.close
    file
  end

  let(:archive) { tempfile.path }

  after { tempfile.close! }

  describe "a subclass that implements nothing" do
    subject(:handler) { bare_subclass.new(verbose: false) }

    let(:bare_subclass) do
      Class.new(described_class) do
        def self.to_s
          "BareCommandHandler"
        end
      end
    end

    it "reports the missing decompressor for #list" do
      expect { handler.list(archive) }.to raise_error(
        NotImplementedError,
        "BareCommandHandler must implement #decompressor_class",
      )
    end

    it "reports the missing decompressor for #info" do
      expect { handler.info(archive) }.to raise_error(
        NotImplementedError,
        "BareCommandHandler must implement #decompressor_class",
      )
    end

    it "reports the missing decompressor for #test" do
      expect { handler.test(archive) }.to raise_error(
        NotImplementedError,
        "BareCommandHandler must implement #decompressor_class",
      )
    end

    it "validates the file before reaching any hook" do
      expect { handler.list("/nonexistent/file.bin") }.to raise_error(
        ArgumentError, "File does not exist: /nonexistent/file.bin"
      )
    end
  end

  describe "a subclass that supplies only a decompressor" do
    subject(:handler) { opened_subclass.new(verbose: false) }

    # Getting past #open_archive makes the render hook the next thing to fail,
    # which is the second error a format author meets.
    let(:opened_subclass) do
      Class.new(described_class) do
        def self.to_s
          "OpenedCommandHandler"
        end

        private

        def decompressor_class
          Class.new do
            def open(file)
              file
            end

            def close(archive)
              archive
            end
          end
        end
      end
    end

    it "reports the missing listing renderer" do
      expect { handler.list(archive) }.to raise_error(
        NotImplementedError,
        "OpenedCommandHandler must implement #render_listing",
      )
    end

    it "reports the missing info renderer" do
      expect { handler.info(archive) }.to raise_error(
        NotImplementedError,
        "OpenedCommandHandler must implement #render_info",
      )
    end

    # #test prints the banner and runs validate_integrity before the render
    # hook, so reaching that hook needs a file the Validator accepts. That the
    # integrity step ran is not asserted here — this example would still pass
    # if it were removed. The LIT characterization covers that.
    it "reports the missing test renderer" do
      cab = Fixtures.for(:cab).path(:basic)

      expect do
        capture_stdout { handler.test(cab) }
      end.to raise_error(
        NotImplementedError,
        "OpenedCommandHandler must implement #render_test_result",
      )
    end
  end

  describe "a format that opts out of the template" do
    # OAB overrides #list, #info and #test, so its #decompressor_class is
    # unreachable in normal use. Widening the visibility in a subclass is how
    # the message gets asserted without reaching in with #send. The message
    # names whichever class is missing the hook, so here it names the subclass.
    let(:exposed_oab) do
      Class.new(Cabriolet::OAB::CommandHandler) do
        def self.to_s
          "OABSubclass"
        end

        public :decompressor_class
      end
    end

    it "explains that the format does not open an archive" do
      expect { exposed_oab.new(verbose: false).decompressor_class }
        .to raise_error(
          NotImplementedError,
          "OABSubclass does not open an archive; " \
          "it overrides #list, #info and #test instead",
        )
    end
  end
end
