require 'AWS'
require 'shell_command'
require 'yaml'
require 'socket'

class EbsSnapshot
  VERSION = '0.0.2'
  attr_reader :config
  
  def self.snapshot
    new.snapshot
  end
  
  def initialize
    check_config
    @config   = YAML::load(File.open('/etc/ebs_snapshot.yml'))
    @suspend  = ShellCommand.new("/usr/sbin/xfs_freeze -f")
    @resume   = ShellCommand.new("/usr/sbin/xfs_freeze -u")
    @hostname = ShellCommand.new("/bin/hostname")
    ec2_connect
  end
  
  def snapshot
    self.config['snapshots'].each do |snapshot|
      if snapshot['db']
        self.db_snapshot(snapshot['path'],snapshot['volume'])
      else
        self.fs_snapshot(snapshot['path'],snapshot['volume'])
      end
    end
  end
  
  def db_snapshot(path,volume)
    require 'sequel' unless Object.const_defined?('Sequel')
    begin
      db_connect
      master_status = lock_db
      description = <<-EOD
DB backup on #{hostname} at #{timestamp}
 volume: #{volume}
 path: #{path}
 master_file: #{master_status[:File]}
 master_pos: #{master_status[:Position]}
      EOD
      snap_out = take_snapshot(path,volume,description)
      snap_out["snapshotId"]
    rescue StandardError => e
      puts e.message
      exit(3)
    end
  end
  
  def fs_snapshot(path,volume)
    begin
      description = <<-EOD
FS backup on #{hostname} at #{timestamp}
 volume: #{volume}
 path: #{path}
      EOD
      snap_out = take_snapshot(path,volume,description)
      snap_out["snapshotId"]
    rescue StandardError => e
      puts e.message
      exit(3)
    end
  end
  
  def ec2_connect
    @ec2 = AWS::EC2::Base.new(
      :access_key_id => @config['global']['ec2_access_key'],
      :secret_access_key => @config['global']['ec2_secret_key']
    )
  end
  
  def db_connect
    auth = [
      @config['global']['db_user'],
      @config['global']['db_pass']
    ].join(':')
    @db = Sequel.connect(
      "mysql://#{auth}@localhost", :single_threaded => true
    )
  end
  
  def take_snapshot(path,volume,description)
    begin
      suspend_filesystem(path)
      snapshot = @ec2.create_snapshot(
        :volume_id => volume, :description => description
      )
      resume_filesystem(path)
      snapshot
    rescue StandardError => e
      resume_filesystem(path)
      raise e
    end
  end
  
  def timestamp
    @timestamp ||= Time.now.strftime("%Y-%m-%d %H:%M:%S")
  end
  
  def hostname
    @hostname ||= Socket.gethostname
  end
  
  def suspend_filesystem(path)
    raise(StandardError, @suspend.stderr) unless @suspend.popen(path)
  end
  
  def resume_filesystem(path)
    raise(StandardError, @resume.stderr) unless @resume.popen(path)
  end
  
  def lock_db
    @db['SLAVE STOP'].first
    @db['FLUSH TABLES WITH READ LOCK'].first
    @db['SHOW MASTER STATUS'].first
  end
  
  def unlock_db
    @db['UNLOCK TABLES'].first
    @db['SLAVE START'].first
  end
  
  protected
  def check_config
    unless File.exists?('/etc/ebs_snapshot.yml')
      puts <<-EOD
\n\n** Configuration file /etc/ebs_snapshot.yml does not exist

# example /etc/ebs_snapshot.yml
# make db true if this is a database volume
global:
  ec2_access_key: xxxxxxxxxxxxxx
  ec2_secret_key: xxxxxxxxxxxxxx
  db_user: user
  db_pass: password

snapshots:
  - path: /mnt/dbvolume
    volume: vol-xxxxxxx
    db: true
  - path: /mnt/othervolume
    volume: vol-xxxxxxx
\n\n
EOD
      exit(3)
    end
  end
end
