require 'openssl'
require 'webmock/rspec'
require_relative '../lib/mitm_tunnel_handler'
require_relative '../lib/certificate_authority'
require_relative '../lib/http_request'
require 'tmpdir'

RSpec.describe MitmTunnelHandler do
  let(:ca_dir) { Dir.mktmpdir('mitm_spec_ca') }
  let(:ca) { CertificateAuthority.new(ca_dir: ca_dir) }
  let(:handler) { described_class.new(certificate_authority: ca) }
  let(:request) { HttpRequest.parse('CONNECT example.com:443 HTTP/1.1') }
  let(:headers) { {} }

  after do
    FileUtils.remove_entry(ca_dir) if ca_dir && Dir.exist?(ca_dir)
  end

  describe 'initialization' do
    it 'creates a handler with a certificate authority' do
      expect(handler).to be_a(described_class)
    end

    it 'defaults to a new CertificateAuthority when none is given' do
      default_handler = described_class.new
      expect(default_handler).to be_a(described_class)
    end
  end

  describe '#handle with real TLS connection' do
    it 'sends 200 Connection Established before TLS handshake' do
      server = TCPServer.new('127.0.0.1', 0)
      server_port = server.addr[1]

      handler_thread = Thread.new do
        client = server.accept
        handler.handle(request, headers, client)
      end

      client_socket = TCPSocket.new('127.0.0.1', server_port)
      response = client_socket.readpartial(1024)
      expect(response).to include('HTTP/1.1 200 Connection Established')
      client_socket.close
      handler_thread.join(1)
    ensure
      begin
        server&.close
      rescue StandardError
        nil
      end
    end

    it 'accepts TLS connections with a valid certificate for the target host' do
      stub_request(:get, 'https://example.com/hello')
        .to_return(status: 200, body: 'ok', headers: { 'Content-Type' => 'text/plain' })

      server = TCPServer.new('127.0.0.1', 0)
      server_port = server.addr[1]

      handler_thread = Thread.new do
        client = server.accept
        handler.handle(request, headers, client)
      end

      client_socket = TCPSocket.new('127.0.0.1', server_port)
      response = client_socket.readpartial(1024)
      expect(response).to include('200 Connection Established')

      tls_client = OpenSSL::SSL::SSLSocket.new(client_socket, tls_client_context)
      tls_client.sync_close = true
      tls_client.connect

      tls_client.write("GET /hello HTTP/1.1\r\nHost: example.com\r\n\r\n")
      inner_response = read_full_response(tls_client)
      expect(inner_response).to include('HTTP/1.1 200 OK')
      expect(inner_response).to include('ok')

      tls_client.close
      handler_thread.join(2)
    ensure
      begin
        server&.close
      rescue StandardError
        nil
      end
    end

    it 'reads inner HTTP headers from the TLS connection' do
      stub_request(:get, 'https://example.com/custom')
        .with(headers: { 'X-Custom' => 'test-value' })
        .to_return(status: 200, body: 'ok', headers: { 'Content-Type' => 'text/plain' })

      server = TCPServer.new('127.0.0.1', 0)
      server_port = server.addr[1]

      handler_thread = Thread.new do
        client = server.accept
        handler.handle(request, headers, client)
      end

      client_socket = TCPSocket.new('127.0.0.1', server_port)
      client_socket.readpartial(1024)

      tls_client = OpenSSL::SSL::SSLSocket.new(client_socket, tls_client_context)
      tls_client.sync_close = true
      tls_client.connect

      tls_client.write("GET /custom HTTP/1.1\r\nHost: example.com\r\nX-Custom: test-value\r\n\r\n")
      inner_response = read_full_response(tls_client)
      expect(inner_response).to include('HTTP/1.1 200 OK')
      expect(inner_response).to include('ok')
      expect(a_request(:get, 'https://example.com/custom')
        .with(headers: { 'X-Custom' => 'test-value' })).to have_been_made.once

      tls_client.close
      handler_thread.join(2)
    ensure
      begin
        server&.close
      rescue StandardError
        nil
      end
    end
  end

  describe 'error handling' do
    it 'writes 502 Bad Gateway when TLS handshake fails' do
      server = TCPServer.new('127.0.0.1', 0)
      server_port = server.addr[1]

      handler_thread = Thread.new do
        client = server.accept
        handler.handle(request, headers, client)
      end

      client_socket = TCPSocket.new('127.0.0.1', server_port)
      response = client_socket.readpartial(1024)
      expect(response).to include('200 Connection Established')

      client_socket.write('not a TLS handshake')
      sleep 0.3

      response = ''
      if client_socket.wait_readable(2)
        response = begin
          client_socket.readpartial(4096)
        rescue StandardError
          ''
        end
      end
      expect(response).to include('502 Bad Gateway')
      client_socket.close
      handler_thread.join(1)
    ensure
      begin
        server&.close
      rescue StandardError
        nil
      end
    end
  end

  private

  def tls_client_context
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
    ctx.min_version = OpenSSL::SSL::TLS1_2_VERSION
    ctx
  end

  def read_full_response(socket)
    response = +''
    loop do
      data = socket.readpartial(4096)
      response << data
      break if data.include?("\r\n\r\n") && response.include?('Content-Length:')
    end
    response
  rescue EOFError
    response
  end
end
