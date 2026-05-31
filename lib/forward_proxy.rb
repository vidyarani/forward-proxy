require 'socket'
require_relative 'request_router'
require_relative 'http_forwarder'
require_relative 'tunnel_handler'
require_relative 'mitm_tunnel_handler'

module ForwardProxy
  DEFAULT_PORT = 10000

  def self.start(port: DEFAULT_PORT, enable_mitm: false, verify_origin: false)
    return if @server && @thread&.alive?

    @port = port
    @server = TCPServer.new('127.0.0.1', @port)
    
    tunnel_handler = enable_mitm ? MitmTunnelHandler.new(verify_origin: verify_origin) : TunnelHandler.new
    
    @thread = Thread.new do
      begin
        loop do
          client = @server.accept
          Thread.new(client) do |sock|
            begin
              RequestRouter.route(sock, http_handler: HttpForwarder.new, tunnel_handler: tunnel_handler)
            rescue StandardError
            ensure
              sock.close rescue nil
            end
          end
        end
      rescue StandardError
        # server closed or thread interrupted, exit cleanly
      end
    end

    sleep 0.05
  end

  def self.port
    @port
  end

  def self.stop
    if @server
      @server.close rescue nil
      if @thread&.alive?
        @thread.join(1)
      end
      @server = nil
      @thread = nil
      @port = nil
    end
  end
end

