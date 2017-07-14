lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'httpray/version'

Gem::Specification.new do |spec|
  spec.name          = "httpray"
  spec.version       = HTTPray::VERSION
  spec.authors       = ["G Gordon Worley III"]
  spec.email         = ["gworley3@gmail.com"]
  spec.description   = %q{Fire-and-forget HTTP requests for Ruby}
  spec.summary       = %q{Like UDP but for HTTP over TCP}
  spec.homepage      = "https://github.com/gworley3/httpray"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.post_install_message = "HTT🙏  for mercy"
end
