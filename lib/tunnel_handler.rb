require 'socket'

class TunnelHandler
  def handle(request, headers, client_socket)
    origin_socket = TCPSocket.new(request.host, request.port)
    client_socket.write("HTTP/1.1 200 Connection Established\r\n\r\n")
    pipe_bidirectionally(client_socket, origin_socket)
  rescue StandardError
    client_socket.write("HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
    client_socket.close rescue nil
  ensure
    origin_socket.close rescue nil
  end

  private

  def pipe_bidirectionally(client_socket, origin_socket)
    threads = []
    threads << Thread.new { copy_stream(client_socket, origin_socket) }
    threads << Thread.new { copy_stream(origin_socket, client_socket) }
    threads.each(&:join)
  end

  def copy_stream(source, destination)
    loop do
      data = source.readpartial(4096)
      destination.write(data)
    end
  rescue EOFError, IOError
    destination.close rescue nil
  end
end
