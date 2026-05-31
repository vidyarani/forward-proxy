require 'socket'
require_relative '../lib/tunnel_handler'
require_relative '../lib/http_request'

RSpec.describe TunnelHandler do
  it 'responds with 200 and pipes raw bytes between client and origin' do
    origin_server = TCPServer.new('127.0.0.1', 0)
    origin_port = origin_server.addr[1]
    request = HttpRequest.new(method: 'CONNECT', host: '127.0.0.1', path: nil, version: 'HTTP/1.1', port: origin_port)
    handler = described_class.new

    client_server = TCPServer.new('127.0.0.1', 0)
    client_port = client_server.addr[1]

    handler_thread = Thread.new do
      client_socket = client_server.accept
      handler.handle(request, {}, client_socket)
    end

    client_socket = TCPSocket.new('127.0.0.1', client_port)
    response_line = client_socket.readpartial(1024)
    expect(response_line).to include('HTTP/1.1 200 Connection Established')

    origin_socket = origin_server.accept
    client_socket.write('hello')
    expect(origin_socket.read(5)).to eq('hello')

    origin_socket.write('world')
    expect(client_socket.read(5)).to eq('world')

    client_socket.close
    origin_socket.close
    handler_thread.join
  ensure
    begin
      origin_server.close
    rescue StandardError
      nil
    end
    begin
      client_server.close
    rescue StandardError
      nil
    end
  end
end
