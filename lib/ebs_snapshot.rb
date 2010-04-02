require 'AWS'
require 'shell_command'
require 'yaml'
require 'socket'

class EbsSnapshot
  VERSION = '0.0.4'
  attr_reader :config, :ec2, :mysql
  
  def self.snapshot
    new.snapshot
  end
  
  def initialize
    check_config
    @config = YAML::load(File.open('/etc/ebs_snapshot.yml'))
    ec2_connect
  end
  
  def hostname
    config['aws']['hostname'] ||= Socket.gethostname
  end
  
  def snapshot
    self.config['snapshots'].each do |volume, args|
      case args["db"]
      when "mysql"
        mysql_snapshot(args["fs"],args["path"],volume)
      else
        file_snapshot(args["fs"],args["path"],volume)
      end
    end
  end
  
  def mysql_snapshot(type,path,volume)
    require 'sequel' unless defined?(Sequel)
    mysql_connect unless mysql
    begin
      file, position = lock_mysql
      description = "#{hostname}:#{path} (#{file}, #{position})"
      snap = take_snapshot(type,path,volume,description)
      unlock_mysql
      snap['snapshotId']
    rescue StandardError => e
      unlock_mysql
      puts e.message
      exit(3)
    end
  end
  
  def file_snapshot(type,path,volume)
    begin
      description = "#{hostname}:#{path}"
      snap = take_snapshot(type,path,volume,description)
      snap['snapshotId']
    rescue StandardError => e
      puts e.message
      exit(3)
    end
  end

  protected
  
  def take_snapshot(type,path,volume,description)
    begin
      freeze_filesystem(type,path)
      ec2.create_snapshot(:volume_id => volume, :description => description)
    ensure
      thaw_filesystem(type,path)
    end
  end
  
  def freeze_filesystem(type,path)
    sync   = ShellCommand.new("/bin/sync")
    raise(StandardError, sync.stderr) unless sync.popen
    freeze = case type
    when "xfs"
      ShellCommand.new("/usr/sbin/xfs_freeze -f")
    when "lvm"
      ShellCommand.new("/sbin/dmsetup suspend")
    end
    if freeze
      raise(StandardError, freeze.stderr) unless freeze.popen(path)
    end
  end
  
  def thaw_filesystem(type,path)
    thaw = case type
    when "xfs"
      ShellCommand.new("/usr/sbin/xfs_freeze -u")
    when "lvm"
      ShellCommand.new("/sbin/dmsetup resume")
    end
    if thaw
      raise(StandardError, thaw.stderr) unless thaw.popen(path)
    end
  end
  
  def mysql_connect
    @mysql = Sequel.connect(
      config['mysql'].update(:single_threaded => true, :adapter => 'mysql')
    )
  end
  
  def lock_mysql
    mysql['SLAVE STOP'].first
    mysql['FLUSH TABLES WITH READ LOCK'].first
    status = mysql['SHOW MASTER STATUS'].first
    [status[:File], status[:Position]]
  end
  
  def unlock_mysql
    mysql['UNLOCK TABLES'].first
    mysql['SLAVE START'].first
  end
  
  def ec2_connect
    @ec2 = AWS::EC2::Base.new(
      :access_key_id => config['aws']['access_key'],
      :secret_access_key => config['aws']['secret_key']
    )
  end
  
  def check_config
    unless File.exists?('/etc/ebs_snapshot.yml')
      puts <<-EOD
\n\n** Configuration file /etc/ebs_snapshot.yml does not exist

# example /etc/ebs_snapshot.yml

# REQUIRED
# will use system hostname if not present
aws:
  access_key: xxxxxxxxxxxxxx
  secret_key: xxxxxxxxxxxxxx
  hostname: myhostname

# mysql authentication information
mysql:
  user: myuser
  password: mypassword

# set db to mysql if a mysql database volume
# set fs to xfs or lvm filesystem for freezing
snapshots:
  vol-xxxxxxx:
    path: /mnt/dbvolume
    fs: xfs
    db: mysql
  vol-yyyyyyy:
    path: /mnt/othervolume
    fs: lvm

EOD
      exit(3)
    end
  end
end
