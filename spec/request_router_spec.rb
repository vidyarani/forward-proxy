require 'stringio'
require_relative '../lib/http_request'
require_relative '../lib/request_router'

class FakeSocket
  attr_reader :read_lines, :written

  def initialize(data)
    @io = StringIO.new(data)
    @read_lines = []
    @written = ''
    @closed = false
  end

  def readline(*args)
    raise EOFError if @closed
    line = @io.readline(*args)
    @read_lines << line
    line
  end

  def write(data)
    @written << data
    data.length
  end

  def close
    @closed = true
  end

  def closed?
    @closed
  end
end

class FakeHandler
  attr_reader :called_with, :header_reads

  def handle(request, headers, socket)
    @called_with = [request, headers, socket]
    @header_reads = socket.read_lines.dup
  end
end

RSpec.describe RequestRouter do
  describe 'routing GET requests' do
    it 'routes GET to the http_handler' do
      socket = FakeSocket.new("GET http://example.com/path HTTP/1.1\r\nHost: example.com\r\n\r\n")
      http_handler = FakeHandler.new
      tunnel_handler = FakeHandler.new

      RequestRouter.route(socket, http_handler: http_handler, tunnel_handler: tunnel_handler)

      expect(http_handler.called_with).not_to be_nil
      expect(http_handler.called_with.first.method).to eq('GET')
      expect(tunnel_handler.called_with).to be_nil
    end
  end

  describe 'routing POST requests' do
    it 'routes POST to the http_handler' do
      socket = FakeSocket.new("POST http://example.com/form HTTP/1.1\r\nHost: example.com\r\nContent-Length: 0\r\n\r\n")
      http_handler = FakeHandler.new
      tunnel_handler = FakeHandler.new

      RequestRouter.route(socket, http_handler: http_handler, tunnel_handler: tunnel_handler)

      expect(http_handler.called_with.first.method).to eq('POST')
      expect(http_handler.called_with.first.path).to eq('/form')
      expect(tunnel_handler.called_with).to be_nil
    end
  end

  describe 'routing CONNECT requests' do
    it 'routes CONNECT to the tunnel_handler' do
      socket = FakeSocket.new("CONNECT example.com:443 HTTP/1.1\r\nHost: example.com\r\n\r\n")
      http_handler = FakeHandler.new
      tunnel_handler = FakeHandler.new

      RequestRouter.route(socket, http_handler: http_handler, tunnel_handler: tunnel_handler)

      expect(tunnel_handler.called_with).not_to be_nil
      expect(tunnel_handler.called_with.first.method).to eq('CONNECT')
      expect(http_handler.called_with).to be_nil
    end
  end

  describe 'reading headers before dispatching' do
    it 'reads all headers before calling the handler' do
      socket = FakeSocket.new(
        "GET http://example.com/path HTTP/1.1\r\n" \
        "Host: example.com\r\n" \
        "X-Test: header-value\r\n" \
        "\r\n"
      )
      http_handler = FakeHandler.new
      tunnel_handler = FakeHandler.new

      RequestRouter.route(socket, http_handler: http_handler, tunnel_handler: tunnel_handler)

      expect(http_handler.called_with).not_to be_nil
      expect(http_handler.header_reads).to include("Host: example.com\r\n", "X-Test: header-value\r\n")
      expect(http_handler.header_reads.last).to eq("\r\n")
    end
  end

  describe 'malformed input handling' do
    it 'writes a 400 response and closes the socket on invalid request line' do
      socket = FakeSocket.new("BADREQUEST\r\n\r\n")
      http_handler = FakeHandler.new
      tunnel_handler = FakeHandler.new

      RequestRouter.route(socket, http_handler: http_handler, tunnel_handler: tunnel_handler)

      expect(socket.written).to include('HTTP/1.1 400 Bad Request')
      expect(socket).to be_closed
      expect(http_handler.called_with).to be_nil
      expect(tunnel_handler.called_with).to be_nil
    end

    it 'writes a 400 response and closes the socket on invalid header line' do
      socket = FakeSocket.new("GET http://example.com/path HTTP/1.1\r\nBadHeaderLine\r\n\r\n")
      http_handler = FakeHandler.new
      tunnel_handler = FakeHandler.new

      RequestRouter.route(socket, http_handler: http_handler, tunnel_handler: tunnel_handler)

      expect(socket.written).to include('HTTP/1.1 400 Bad Request')
      expect(socket).to be_closed
      expect(http_handler.called_with).to be_nil
      expect(tunnel_handler.called_with).to be_nil
    end
  end
end
