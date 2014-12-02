# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'testmore/version'

Gem::Specification.new do |spec|
  spec.name          = "dummy-gem-dont-publish"
  spec.version       = Testmore::VERSION
end
