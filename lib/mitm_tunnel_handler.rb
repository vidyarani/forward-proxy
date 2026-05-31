require 'socket'
require 'openssl'
require_relative 'certificate_authority'
require_relative 'http_request'
require_relative 'http_forwarder'

class MitmTunnelHandler
  def initialize(certificate_authority: nil, verify_origin: false)
    @ca = certificate_authority || CertificateAuthority.new
    @verify_origin = verify_origin
  end

  def handle(request, _headers, client_socket)
    client_socket.write("HTTP/1.1 200 Connection Established\r\n\r\n")
    client_socket.flush

    cert, key = @ca.certificate_for(request.host)
    tls_server_ctx = OpenSSL::SSL::SSLContext.new
    tls_server_ctx.cert = cert
    tls_server_ctx.key = key
    tls_server_ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
    tls_server_ctx.min_version = OpenSSL::SSL::TLS1_2_VERSION
    tls_server_ctx.max_version = OpenSSL::SSL::TLS1_3_VERSION

    tls_server_ctx.alpn_protocols = ['http/1.1'] if tls_server_ctx.respond_to?(:alpn_protocols=)

    if tls_server_ctx.respond_to?(:alpn_select_cb=)
      tls_server_ctx.alpn_select_cb = lambda do |protocols|
        protocols.include?('http/1.1') ? 'http/1.1' : protocols.first
      end
    end

    tls_client_socket = OpenSSL::SSL::SSLSocket.new(client_socket, tls_server_ctx)
    tls_client_socket.sync_close = true
    tls_client_socket.accept

    inner_request_line = tls_client_socket.readline.chomp
    inner_headers = read_headers(tls_client_socket)
    inner_request = HttpRequest.parse(inner_request_line, host: inner_headers['Host'], default_scheme: 'https')
    body = read_body(tls_client_socket, inner_headers)

    forwarder = HttpForwarder.new(use_ssl: true, verify_origin: @verify_origin)
    forwarder.handle(inner_request, inner_headers, tls_client_socket, body)
  rescue StandardError => e
    warn "MITM error for #{request.host}: #{e.class}: #{e.message}"
    warn e.backtrace.join("\n")
    begin
      client_socket.write("HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
    rescue StandardError
      nil
    end
    begin
      client_socket.close
    rescue StandardError
      nil
    end
  ensure
    begin
      tls_client_socket&.close
    rescue StandardError
      nil
    end
  end

  private

  def read_headers(socket)
    headers = {}
    loop do
      line = socket.readline
      break if ["\r\n", "\n"].include?(line)

      name, value = line.chomp.split(':', 2)
      raise ArgumentError, 'invalid header line' unless name && value

      headers[name.strip] = value.strip
    end
    headers
  end

  def read_body(socket, headers)
    return nil unless headers['Content-Length']

    length = headers['Content-Length'].to_i
    socket.read(length) if length.positive?
  end
end
