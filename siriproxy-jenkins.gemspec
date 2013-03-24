# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'version'

Gem::Specification.new do |spec|
  spec.name          = 'siriproxy-jenkins'
  spec.version       = SiriProxyJenkins::VERSION
  spec.authors       = ['Tweten,Michael']
  spec.email         = ['Michael.Tweten@cerner.com']
  spec.description   = %q{Siri Proxy plugin to kick off jenkins builds.}
  spec.summary       = %q{Experimental playground plugin that simply attempts to trigger some jenkins builds.}
  spec.homepage      = ''

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'

  spec.add_runtime_dependency 'text', '~> 1.2.1'
  spec.add_runtime_dependency 'rest-client', '~> 1.6.7'
  spec.add_runtime_dependency 'prowl', '~> 0.1.3'
end
