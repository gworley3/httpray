require 'uri'
require 'openssl'
require 'socket'

require_relative 'httpray/version'

module HTTPray
  class Timeout < StandardError; end

  DEFAULT_HEADERS = {
    "User-Agent" => "HTTPray #{VERSION}",
    "Accept" => "*/*",
    "Connection" => "keep-alive"
  }.freeze

  class Connection
    def initialize(host, port, timeout = 1, ssl_context = nil, retry_count = 1)
      @host = host
      @port = port
      @timeout = timeout
      @ssl_context = ssl_context
      @retry_count = retry_count
      @socket = connect
    end

    # public

    def socket
      @socket
    end

    def request!(method, uri, headers = {}, body = nil)
      tries ||= 0
      begin
        IO.select([@socket], [@socket], [@socket], @timeout) if @socket
      rescue; end
      @socket = connect unless @socket && !@socket.closed?
      socket = @socket
      uri = URI.parse(uri) unless URI === uri

      headers = DEFAULT_HEADERS.merge(headers).merge("Host" => uri.host)
      headers["Content-Length"] = body.bytesize if body

      socket.write_nonblock "#{method} #{uri.request_uri} HTTP/1.0\r\n"
      headers.each do |header, value|
        socket.write_nonblock "#{header}: #{value}\r\n"
      end
      socket.write_nonblock "\r\n"
      socket.write_nonblock body if body
      socket
    rescue
      @socket.close
      if tries < @retry_count
        tries += 1
        retry
      end
    end

    def request(*args)
      socket = request!(*args)
      yield(socket) if block_given?
    end

    # private

    def connect2
      address = Socket.getaddrinfo(@host, nil, Socket::AF_INET).first[3]
      socket_address = Socket.pack_sockaddr_in(@port, address)

      socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

      expire_time = Time.now + @timeout
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
      if @ssl_context
        socket = OpenSSL::SSL::SSLSocket.new(socket, @ssl_context)
        socket.hostname = @host
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
      return socket, original_socket
    end

    def connect
      socket, _ = connect2
      socket
    end
  end

  def self.request!(method, uri, headers = {}, body = nil, timeout = 1, ssl_context = nil)
    uri = URI.parse(uri) unless URI === uri
    ssl_context = nil
    ssl_context = OpenSSL::SSL::SSLContext.new if uri.scheme == "https"
    ark = Connection.new(uri.host, uri.port, timeout, ssl_context)
    ark.request!(method, uri, {"Connection" => ""}.merge(headers), body)
  end

  def self.request(*args)
    socket = request!(*args)
    yield(socket) if block_given?
  ensure
    socket.close if socket && !socket.closed?
  end
end
