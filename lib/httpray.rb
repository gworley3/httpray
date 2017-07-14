require 'uri'
require 'openssl'
require 'socket'

require_relative 'httpray/version'

module HTTPray
  class Timeout < StandardError; end

  DEFAULT_HEADERS = {
    "User-Agent" => "HTTPray #{VERSION}",
    "Accept" => "*/*"
  }.freeze

  def self.request2!(method, uri, headers = {}, body = nil, timeout = 1, ssl_context = nil)
    uri = URI.parse(uri) unless URI === uri
    address = Socket.getaddrinfo(uri.host, nil, Socket::AF_INET).first[3]
    socket_address = Socket.pack_sockaddr_in(uri.port, address)

    socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

    expire_time = Time.now + timeout
    begin
      raise Timeout if Time.now > expire_time
      socket.connect_nonblock(socket_address)
    rescue IO::WaitReadable, IO::WaitWritable
      select_timeout = expire_time - Time.now
      select_timeout = 0 if select_timeout < 0
      IO.select([socket], [socket], [socket], select_timeout)
      retry
    end

    original_socket = socket
    if uri.scheme == "https"
      ssl_context ||= OpenSSL::SSL::SSLContext.new
      socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
      socket.hostname = uri.host
      socket.sync_close = true
      begin
        raise Timeout if Time.now > expire_time
        socket.connect_nonblock
      rescue IO::WaitReadable, IO::WaitWritable
        select_timeout = expire_time - Time.now
        select_timeout = 0 if select_timeout < 0
        IO.select([socket.io], [socket.io], [socket.io], select_timeout)
        retry
      end
    end

    headers = DEFAULT_HEADERS.merge(headers).merge("Host" => uri.host)
    headers["Content-Length"] = body.bytesize if body

    socket.write_nonblock "#{method} #{uri.request_uri} HTTP/1.0\r\n"
    headers.each do |header, value|
      socket.write_nonblock "#{header}: #{value}\r\n"
    end
    socket.write_nonblock "\r\n"
    socket.write_nonblock body if body
    return socket, original_socket
  end

  def self.request!(*args)
    socket, _ = request2!(*args)
    socket
  end

  def self.request(*args)
    socket = request!(*args)
    yield(socket) if block_given?
  ensure
    socket.close if socket && !socket.closed?
  end
end
