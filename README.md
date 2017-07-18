# httpray
Non-blocking HTTP library for Ruby

[![Gem Version](https://badge.fury.io/rb/httpray.svg)](https://badge.fury.io/rb/httpray)

Started out the same as the [fire-and-forget](https://github.com/mattetti/fire-and-forget) gem but with a more exposed interface, TLS support, and a better name. Added ideas from [tcp_timeout](https://github.com/lann/tcp-timeout-ruby) and accidentally ended up creating a light-weight, non-blocking HTTP client.

It differs from other Ruby HTTP libraries that support async because it doesn't use Threads, making HTTPray much less resource intensive to use since it instead directly implements HTTP/HTTPS 1.0 using `Socket` and `IO#select` for timeouts. You can optionally ask to be handed back the socket before it is closed in case you want to listen for a response, but that's not really what you're here for.

Great for use with sending data to HTTP endpoints for which you are willing to accept a UDP-style best-effort approach, but with the added guarantee of TCP that the packets made it to the server. Only the server will know what it did with the data, though!

## Install

```ruby
gem "httpray"
```

## Use

```ruby
require 'httpray'

# def HTTParty.request!(method, uri, headers = {}, body = nil, timeout = 1, ssl_context = nil)

# send an HTTP request and don't listen for the response
HTTPray.request(
  "POST",
  "https://your.diety/prayers",
  {"Content-Type" => "application/prayer"},
  "It's me, Margret",
  1) # timeout in seconds

# party with a response, but costs a Fiber
HTTPray.request("GET", "https://your.diety/answered_prayers") do |socket|
  socket.gets
end

# party dangerously (you have to close your own socket!)
socket = HTTPray.request!("GET", "https://your.diety/answered_prayers")
puts socket.gets
socket.close

# use a persistent connection to keep the party rolling
# will automatically reconnect if connection is lost
uri = URI.parse("https://your.diety/pray")
ark = HTTPray::Connection.new(
  uri.host,
  uri.port,
  1, #timeout
  OpenSSL::SSL::SSLContext.new, #ssl context
  1, #retries on error
  10) #seconds to wait after all retries failed before trying again on a subsequent request
ark.request("POST", uri, 
  {"Content-Type" => "application/prayer"},
  "Why did it have to be snakes?")
ark.socket.close
ark.request("POST", uri, 
  {"Content-Type" => "application/prayer"},
  "Don't call me junior!")

```

## Help

HTTPray has minimal convenience and sanitization features because I didn't need them. All that it does is fill in the Host, User-Agent, Accept, and Content-Length headers for you. The body must be a string, so convert it yourself first. The URI can be a `URI` or a `String` that will go through `URI.parse`. You're welcome.

If you're using `Connection` with TLS you need to provide an `OpenSSL::SSL::SSLContext` when creating the connection. `HTTPray.request!` is more forgiving and if you don't give it one it will create it for you if needed. `Connection` also has some fancy retry and circuit breaker logic so you can assume your request always writes even if it doesn't without major performance impacts.

Timeout support does not extend to the response since you just get back a `Socket`. You're own your own for how you want to handle that.

If you want it to be easier to use, feel free to submit pull requests. As long as you don't break existing functionality I will probably accept them.

## Tests

There are some tests that exercise the code paths. You can run them with:

```bash
ruby -I . test/httparty_test.rb
```

Unfortunately they have to hit real network endpoints, so they won't work without a network.
