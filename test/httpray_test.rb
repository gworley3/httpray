require 'minitest/autorun'
require 'lib/httpray'
require 'benchmark'
require 'net/http'

class HTTPrayTest < MiniTest::Unit::TestCase
  def test_request_timesout_with_short_timeout
    assert_raises HTTPray::Timeout do
      HTTPray.request("GET", "httppppp://httpbin.org/status/200", {}, nil, 0)
    end
  end
  def test_request_timesout_with_bad_address
    assert_raises HTTPray::Timeout do
      HTTPray.request("GET", "httppppp://httpbin.org/status/200")
    end
  end
  def test_request_sends
    HTTPray.request("GET", "http://httpbin.org/get")
    assert true
  end
  def test_request_receives_response
    HTTPray.request("GET", "http://httpbin.org/status/200") do |socket|
      assert_equal "HTTP/1.1 200 OK\r\n", socket.gets
    end
  end
  def test_secure_request_timesout_with_short_timeout
    assert_raises HTTPray::Timeout do
      HTTPray.request("GET", "https://httpbin.org/status/200", {}, nil, 0)
    end
  end
  def test_secure_request_sends
    HTTPray.request("GET", "https://httpbin.org/get")
    assert true
  end
  def test_all_options_accepted
    HTTPray.request(
      "POST",
      "https://httpbin.org/post",
      {"Content-Type" => "application/x-www-form-urlencoded"},
      "q=httpray",
      5,
      OpenSSL::SSL::SSLContext.new) do |socket|
        assert_equal "HTTP/1.1 200 OK\r\n", socket.gets
      end
  end
  def test_original_socket_closed_with_ssl
    uri = URI.parse("https://httpbin.org/get")
    ark = HTTPray::Connection.new(uri.host, uri.port, 1, OpenSSL::SSL::SSLContext.new)
    ark.socket.close
    socket, original_socket = ark.connect2
    refute_same socket, original_socket
    refute socket.closed?
    refute original_socket.closed?
    socket.close
    assert socket.closed?
    assert original_socket.closed?
  end
  def test_original_socket_closed_without_ssl
    uri = URI.parse("http://httpbin.org/get")
    ark = HTTPray::Connection.new(uri.host, uri.port, 1, nil)
    ark.socket.close
    socket, original_socket = ark.connect2
    assert_same socket, original_socket
    refute socket.closed?
    refute original_socket.closed?
    socket.close
    assert socket.closed?
    assert original_socket.closed?
  end
  def test_faster_than_net_http
    uri = URI.parse("http://httpbin.org/delay/1")
    net_http_time = Benchmark.realtime do
      2.times { Net::HTTP.get(uri) }
    end
    httpray_time = Benchmark.realtime do
      2.times { HTTPray.request("GET", uri) }
    end
    assert httpray_time < net_http_time
  end
  def test_persistent_connection_faster_than_ephemeral
    uri = URI.parse("http://httpbin.org/delay/1")
    persistent_time = Benchmark.realtime do
      ark = HTTPray::Connection.new(uri.host, uri.port)
      3.times { ark.request("GET", uri) }
    end
    ephemeral_time = Benchmark.realtime do
      3.times { HTTPray.request("GET", uri) }
    end
    assert persistent_time < ephemeral_time
  end
  def test_reconnects_on_request_if_necessary
    uri = URI.parse("http://httpbin.org/get")
    ark = HTTPray::Connection.new(uri.host, uri.port, 1, nil)
    original_socket = ark.socket
    ark.request("GET", uri)
    assert_same original_socket, ark.socket
    ark.socket.close
    assert original_socket.closed?
    ark.request("GET", uri)
    refute_same original_socket, ark.socket
  end
  def test_retries_on_random_errors
    uri = URI.parse("http://httpbin.org/deny")
    ark = HTTPray::Connection.new(uri.host, uri.port, 1, nil)
    ark.socket.stub(:write_nonblock, lambda { |*args| raise "Broken pipe" }) do
      ark.request("GET", uri, {"Connection" => ""})
    end
  end
  def test_retries_stopped_by_circuit_breaker
    uri = URI.parse("http://httpbin.org/deny")
    ark = HTTPray::Connection.new(uri.host, uri.port, 1, nil, 0, 2)
    # force retries to expire
    ark.socket.stub(:write_nonblock, lambda { |*args| raise "Broken pipe" }) do
      assert_raises RuntimeError do; ark.request("GET", uri, {"Connection" => ""}); end
    end
    ark.stub(:reconnect, ark.socket) do #prevent reconnect of closed socket from previous error
      ark.socket.stub(:write_nonblock, lambda { |*args| raise "Broken pipe" }) do
        assert_raises HTTPray::CircuitBreakerError do; ark.request("GET", uri, {"Connection" => ""}); end
      end
    end
    sleep(2)
    ark.request("GET", uri, {"Connection" => ""})
  end
end
