require 'socket'

module ForwardProxy
  DEFAULT_PORT = 10000

  def self.start(port: DEFAULT_PORT)
    return if @server && @thread&.alive?

    @port = port
    @server = TCPServer.new('127.0.0.1', @port)
    @thread = Thread.new do
      begin
        loop do
          client = @server.accept
          # keep the connection open until the client closes it
          Thread.new(client) do |sock|
            begin
              # simple read loop to hold the connection; discard data
              while (data = sock.readpartial(1024))
                # no-op
              end
            rescue EOFError, IOError
            ensure
              sock.close rescue nil
            end
          end
        end
      rescue IOError
        # server closed, exit thread
      end
    end

    # small pause to ensure the server is bound before returning
    sleep 0.05
  end

  def self.port
    @port
  end

  def self.stop
    if @server
      @server.close rescue nil
      @thread.kill if @thread&.alive?
      @server = nil
      @thread = nil
      @port = nil
    end
  end
end
