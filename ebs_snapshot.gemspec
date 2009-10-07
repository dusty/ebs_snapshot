Gem::Specification.new do |s| 
  s.name = "ebs_snapshot" 
  s.version = "0.0.1" 
  s.author = "Dusty Doris" 
  s.email = "github@dusty.name" 
  s.homepage = "http://code.dusty.name" 
  s.platform = Gem::Platform::RUBY
  s.summary = "Take snapshots of ebs volumes on EC2"
  s.description = "Take snapshots of ebs volumes on EC2"
  s.files = [
    "README.txt",
    "lib/ebs_snapshot.rb",
    "bin/ebs_snapshot",
    "test/test_ebs_snapshot.rb"
  ]
  s.has_rdoc = true 
  s.extra_rdoc_files = ["README.txt"]
  s.executables = ['ebs_snapshot']
  s.add_dependency('dusty-shell_command')
  s.add_dependency('amazon-ec2')
  s.rubyforge_project = "none"
end
