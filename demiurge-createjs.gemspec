# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'demiurge/createjs/version'

Gem::Specification.new do |spec|
  spec.name          = "demiurge-createjs"
  spec.version       = Demiurge::Createjs::VERSION
  spec.authors       = ["Noah Gibbs"]
  spec.email         = ["the.codefolio.guy@gmail.com"]

  spec.summary       = %q{WebSocket transport and CreateJS-based browser display for Demiurge.}
  spec.homepage      = "https://github.com/noahgibbs/demiurge-createjs"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"

  spec.add_runtime_dependency "demiurge", "~> 0.2.0"
  spec.add_runtime_dependency "thin"
  #spec.add_runtime_dependency "puma"
  spec.add_runtime_dependency "faye-websocket"
  spec.add_runtime_dependency "multi_json"
  spec.add_runtime_dependency "tmx"
  spec.add_runtime_dependency "therubyracer"
  spec.add_runtime_dependency "rack-coffee"

end
