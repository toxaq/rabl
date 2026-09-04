# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rabl/version"

Gem::Specification.new do |s|
  s.name        = "rabl"
  s.version     = Rabl::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Nathan Esquenazi"]
  s.email       = ["nesquena@gmail.com"]
  s.homepage    = "https://github.com/nesquena/rabl"
  s.summary     = %q{General ruby templating with json support}
  s.description = %q{General ruby templating with json support}
  s.license     = 'MIT'

  s.files         = `git ls-files -z -- {*.md,MIT-LICENSE,lib}`.split("\x0").sort
  s.require_paths = ["lib"]

  s.required_ruby_version = '>= 3.0'

  s.add_dependency "activesupport", '>= 6.0'
end
