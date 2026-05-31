require_relative 'http_request'

# Reads the first line and headers from a client socket, parses them into
# an HttpRequest, then dispatches to the correct injected handler.
#
# Responsibilities (this class only):
#   - Read the raw request line and headers from the socket
#   - Build an HttpRequest value object via HttpRequest.parse
#   - Call http_handler for GET/POST/etc, tunnel_handler for CONNECT
#   - Write a 400 response and close the socket on malformed input
#
# Deliberately knows nothing about how HTTP forwarding or tunnelling works.
# Both handlers are injected — this class is never coupled to concrete
# implementations, which keeps it fully unit-testable without a real network.
class RequestRouter
  def self.route(socket, http_handler:, tunnel_handler:)
    request_line = socket.readline.chomp
    request = HttpRequest.parse(request_line)

    headers = {}
    loop do
      line = socket.readline
      break if ["\r\n", "\n"].include?(line)

      name, value = line.chomp.split(':', 2)
      raise ArgumentError, 'invalid header line' unless name && value

      headers[name.strip] = value.strip
    end

    if request.method == 'CONNECT'
      tunnel_handler.handle(request, headers, socket)
    else
      http_handler.handle(request, headers, socket)
    end
  rescue StandardError
    socket.write("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
    socket.close
  end
end
