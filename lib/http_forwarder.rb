require 'net/http'

class HttpForwarder
  def handle(request, headers, client_socket, body = nil)
    response = fetch_upstream(request, headers, body)
    write_response(client_socket, response)
  rescue StandardError
    client_socket.write("HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
    client_socket.close rescue nil
  end

  private

  def fetch_upstream(request, headers, body)
    http = Net::HTTP.new(request.host, request.port)
    upstream_request = build_upstream_request(request, headers, body)
    http.request(upstream_request)
  end

  def build_upstream_request(request, headers, body)
    klass = Net::HTTP.const_get(request.method.capitalize)
    upstream_request = klass.new(request.path)

    headers.each do |name, value|
      next if name.to_s.downcase == 'host'
      upstream_request[name] = value
    end

    upstream_request.body = body if body
    upstream_request
  end

  STATUS_REASON_PHRASES = {
    '200' => 'OK',
    '201' => 'Created',
    '400' => 'Bad Request',
    '502' => 'Bad Gateway'
  }.freeze

  HOP_BY_HOP_HEADERS = %w[
    connection
    keep-alive
    proxy-authenticate
    proxy-authorization
    te
    trailer
    transfer-encoding
    upgrade
  ].freeze

  def write_response(client_socket, response)
    reason = response.message.to_s.strip
    reason = default_reason_phrase(response.code) if reason.empty?

    body = response.body.to_s
    headers = filtered_headers(response)
    headers['Content-Length'] = body.bytesize.to_s unless headers.key?('Content-Length')
    headers['Connection'] = 'close'

    client_socket.write("HTTP/1.1 #{response.code} #{reason}\r\n")
    headers.each do |name, value|
      client_socket.write("#{name}: #{value}\r\n")
    end
    client_socket.write("\r\n")
    client_socket.write(body)
  end

  def filtered_headers(response)
    headers = {}
    response.each_header do |name, value|
      next if HOP_BY_HOP_HEADERS.include?(name.downcase)
      headers[name.split('-').map(&:capitalize).join('-')] = value
    end
    headers
  end

  def default_reason_phrase(code)
    STATUS_REASON_PHRASES[code.to_s] || ''
  end
end
