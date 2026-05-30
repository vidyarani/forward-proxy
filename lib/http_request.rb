require 'uri'

class HttpRequest
  attr_reader :method, :host, :path, :version, :port

  def initialize(method:, host:, path:, version:, port:)
    @method = method
    @host = host
    @path = path
    @version = version
    @port = port
    freeze
  end

  def self.parse(request_line)
    method, target, version = request_line.strip.split(' ', 3)
    raise ArgumentError, 'invalid request line' unless method && target && version

    if method == 'CONNECT'
      host, port_str = target.split(':', 2)
      raise ArgumentError, 'invalid CONNECT target' unless host && port_str

      port = Integer(port_str)
      new(method: method, host: host, path: nil, version: version, port: port)
    else
      uri = URI(target)
      raise ArgumentError, 'invalid HTTP URI' unless uri.host

      request_path = uri.path.empty? ? '/' : uri.path
      request_path += "?#{uri.query}" if uri.query
      request_path += "##{uri.fragment}" if uri.fragment

      port = uri.port || default_port_for_scheme(uri.scheme)
      new(method: method, host: uri.host, path: request_path, version: version, port: port)
    end
  rescue URI::InvalidURIError
    raise ArgumentError, 'invalid request line'
  end

  def self.default_port_for_scheme(scheme)
    case scheme&.downcase
    when 'https' then 443
    else 80
    end
  end
end
