# frozen_string_literal: true

require "stringio"

# Captures whatever a block writes to stdout
#
# The command handlers report by calling puts, so asserting on their output
# means redirecting $stdout around the call. Restoring it has to happen in an
# ensure, or one raising example silently swallows the rest of the suite's
# output.
module StdoutCapture
  # Run a block with $stdout redirected
  #
  # @return [Array(String, Object)] What was printed, and the block's value
  def capture_stdout
    buffer = StringIO.new
    original = $stdout
    $stdout = buffer
    value = yield
    [buffer.string, value]
  ensure
    $stdout = original
  end

  # Run a block with $stdout redirected, trapping any error it raises
  #
  # Used to assert on output written before a failure, which the plain capture
  # cannot reach because the exception propagates past it.
  #
  # @return [Array(String, StandardError, nil)] What was printed, and the error
  def capture_stdout_failure
    capture_stdout do
      yield
      nil
    rescue StandardError => e
      e
    end
  end
end
