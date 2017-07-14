require 'minitest/autorun'
require 'lib/httpray'

class HTTPrayTest < MiniTest::Unit::TestCase
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
    socket, original_socket = HTTPray.request2!(
      "GET",
      "https://httpbin.org/delay/10")
    refute_same socket, original_socket
    refute socket.closed?
    refute original_socket.closed?
    socket.close
    assert socket.closed?
    assert original_socket.closed?
  end
  def test_original_socket_closed_without_ssl
    socket, original_socket = HTTPray.request2!(
      "GET",
      "http://httpbin.org/delay/10")
    assert_same socket, original_socket
    refute socket.closed?
    refute original_socket.closed?
    socket.close
    assert socket.closed?
    assert original_socket.closed?
  end
end
