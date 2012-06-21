# -*- encoding: utf-8 -*-
require File.expand_path('../lib/ebs_snapshot/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Dusty Doris"]
  gem.email         = ["dusty@doris.name"]
  gem.description   = %q{Take snapshots on EBS volumes.}
  gem.summary       = %q{Take snapshots on EBS volumes.  Supports MySQL and LVM/XFS fileystem freeze.}
  gem.homepage      = "https://github.com/dusty/ebs_snapshot"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "ebs_snapshot"
  gem.require_paths = ["lib"]
  gem.version       = EbsSnapshot::VERSION

  gem.add_runtime_dependency('amazon-ec2')
  gem.add_runtime_dependency('open4')
  # gem.add_runtime_dependency('mysql2')
end
