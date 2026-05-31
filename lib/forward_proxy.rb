require 'socket'
require_relative 'request_router'
require_relative 'http_forwarder'
require_relative 'tunnel_handler'
require_relative 'mitm_tunnel_handler'

module ForwardProxy
  DEFAULT_PORT = 10_000

  def self.start(port: DEFAULT_PORT, bind: '127.0.0.1', enable_mitm: false, verify_origin: false)
    return if @server && @thread&.alive?

    @port = port
    @bind = bind
    @server = TCPServer.new(@bind, @port)

    tunnel_handler = enable_mitm ? MitmTunnelHandler.new(verify_origin: verify_origin) : TunnelHandler.new

    @thread = Thread.new do
      loop do
        client = @server.accept
        Thread.new(client) do |sock|
          RequestRouter.route(sock, http_handler: HttpForwarder.new, tunnel_handler: tunnel_handler)
        rescue StandardError
        ensure
          begin
            sock.close
          rescue StandardError
            nil
          end
        end
      end
    rescue StandardError
      # server closed or thread interrupted, exit cleanly
    end

    sleep 0.05
  end

  def self.port
    @port
  end

  def self.stop
    return unless @server

    begin
      @server.close
    rescue StandardError
      nil
    end
    @thread.join(1) if @thread&.alive?
    @server = nil
    @thread = nil
    @port = nil
  end
end
