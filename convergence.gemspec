# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'convergence/version'

Gem::Specification.new do |spec|
  spec.name          = 'convergence'
  spec.version       = Convergence::VERSION
  spec.authors       = ['Shinsuke Nishio']
  spec.email         = ['nishio@densan-labs.net']
  spec.summary       = 'DB Schema management tool'
  spec.description   = 'DB Schema management tool'
  spec.homepage      = 'https://github.com/nishio-dens/convergence'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'mysql2'
  spec.add_dependency 'diff-lcs'
  spec.add_dependency 'diffy'
  spec.add_dependency 'thor', '~> 0.20'

  spec.required_ruby_version = ">= 2.4.0"

  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '>= 3.5'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'guard'
  spec.add_development_dependency 'guard-rspec'
end
