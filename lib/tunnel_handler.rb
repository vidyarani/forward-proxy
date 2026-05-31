require 'socket'

class TunnelHandler
  def handle(request, _headers, client_socket)
    origin_socket = TCPSocket.new(request.host, request.port)
    client_socket.write("HTTP/1.1 200 Connection Established\r\n\r\n")
    pipe_bidirectionally(client_socket, origin_socket)
  rescue StandardError
    client_socket.write("HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
    begin
      client_socket.close
    rescue StandardError
      nil
    end
  ensure
    begin
      origin_socket.close
    rescue StandardError
      nil
    end
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
  rescue IOError
    begin
      destination.close
    rescue StandardError
      nil
    end
  end
end
