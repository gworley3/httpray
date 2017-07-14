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

  def self.request2!(method, uri, headers = {}, body = "", timeout = 1, ssl_context = nil)
    uri = URI.parse(uri) unless URI === uri
    address = Socket.getaddrinfo(uri.host, nil, Socket::AF_INET).first[3]
    socket_address = Socket.pack_sockaddr_in(uri.port, address)

    socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

    begin
      socket.connect_nonblock(socket_address)
    rescue Errno::EINPROGRESS
      if IO.select(nil, [socket], [socket], timeout)
        begin
          socket.connect_nonblock(socket_address)
        rescue Errno::EISCONN
          # connected
        end
      else
        raise Timeout
      end
    end

    original_socket = socket
    if uri.scheme == "https"
      ssl_context ||= OpenSSL::SSL::SSLContext.new
      socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
      socket.hostname = uri.host
      socket.sync_close = true
      socket.connect
    end

    headers = DEFAULT_HEADERS.merge(headers).merge(
      "Host" => uri.host,
      "Content-Length" => body.bytesize)

    if IO.select(nil, [socket], [socket], 1)
      socket.puts "#{method} #{uri.request_uri} HTTP/1.0\r\n"
      headers.each do |header, value|
        socket.puts "#{header}: #{value}\r\n"
      end
      socket.puts "\r\n"
      socket.puts body

      yield(socket) if block_given?
    else
      raise Timeout
    end
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
