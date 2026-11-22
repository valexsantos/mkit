# frozen_string_literal: true

# Records what a listener sends through the websocket.
class FakeWs
  attr_reader :sent, :handler

  def initialize
    @sent = []
    @closed = false
  end

  def send(data)
    @sent << data
  end

  def onmessage(&block)
    @handler = block
  end

  def close_websocket
    @closed = true
  end

  def closed?
    @closed
  end
end
