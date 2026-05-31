require 'uri'

class HttpRequest
  attr_reader :method, :host, :path, :version, :port, :scheme

  def initialize(method:, host:, path:, version:, port:, scheme: 'http')
    @method = method
    @host = host
    @path = path
    @version = version
    @port = port
    @scheme = scheme
    freeze
  end

  def self.parse(request_line, host: nil, default_scheme: 'http')
    method, target, version = request_line.strip.split(' ', 3)
    raise ArgumentError, 'invalid request line' unless method && target && version

    if method == 'CONNECT'
      build_connect_request(method, target, version)
    else
      if target.start_with?('/')
        raise ArgumentError, 'missing Host header for origin-form request' unless host
        target = "#{default_scheme}://#{host}#{target}"
      end
      build_standard_request(method, target, version)
    end
  rescue URI::InvalidURIError
    raise ArgumentError, 'invalid request line'
  end

  def self.build_standard_request(method, target, version)
    uri = URI(target)
    raise ArgumentError, 'invalid HTTP URI' unless uri.host

      request_path = uri.path.empty? ? '/' : uri.path
      request_path += "?#{uri.query}" if uri.query
      request_path += "##{uri.fragment}" if uri.fragment

      port = uri.port || default_port_for_scheme(uri.scheme)
      scheme = uri.scheme&.downcase || 'http'
      new(method: method, host: uri.host, path: request_path, version: version, port: port, scheme: scheme)
  end

  def self.build_connect_request(method, target, version)
    host, port_str = target.split(':', 2)
    raise ArgumentError, 'invalid CONNECT target' unless host && port_str

      port = Integer(port_str)
      new(method: method, host: host, path: nil, version: version, port: port)
  end

  def self.default_port_for_scheme(scheme)
    case scheme&.downcase
    when 'https' then 443
    else 80
    end
  end
end
