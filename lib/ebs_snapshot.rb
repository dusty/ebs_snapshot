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
      take_snapshot(type,path,volume,description)
    ensure
      unlock_mysql
    end
  end
  
  def file_snapshot(type,path,volume)
    description = "#{hostname}:#{path}"
    snap = take_snapshot(type,path,volume,description)
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
    sync = ShellCommand.new("/bin/sync")
    raise(StandardError, sync.stderr) unless sync.popen
    freeze = case type
    when "xfs"
      ShellCommand.new("/usr/sbin/xfs_freeze -f")
    when "lvm"
      ShellCommand.new("/sbin/dmsetup suspend")
    end
    raise(StandardError, freeze.stderr) unless (!freeze || freeze.popen(path))
  end
  
  def thaw_filesystem(type,path)
    thaw = case type
    when "xfs"
      ShellCommand.new("/usr/sbin/xfs_freeze -u")
    when "lvm"
      ShellCommand.new("/sbin/dmsetup resume")
    end
    raise(StandardError, thaw.stderr) unless (!thaw || thaw.popen(path))
  end
  
  def mysql_connect
    @mysql = Sequel.connect(
      config['mysql'].update(:single_threaded => true, :adapter => 'mysql')
    )
  end
  
  def lock_mysql
    mysql['FLUSH TABLES WITH READ LOCK'].first
    status = mysql['SHOW MASTER STATUS'].first
    [status[:File], status[:Position]]
  end
  
  def unlock_mysql
    mysql['UNLOCK TABLES'].first
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

** Configuration file /etc/ebs_snapshot.yml does not exist

##
# /etc/ebs_snapshot.yml

##
# aws authentication
#
# hostname you want to display in snapshot description
aws:
  access_key: xxxxxxxxxxxxxx
  secret_key: xxxxxxxxxxxxxx
  hostname: myhostname

##
# mysql authentication information
mysql:
  user: myuser
  password: mypassword

##
# Snapshots
#
# set db to mysql if a mysql database volume
#
# set fs to xfs or lvm filesystem for freezing
#
# set path to mount point for xfs
# set path to lvm mapper for lvm
snapshots:
  vol-xxxxxxx:
    path: /mnt/dbvolume
    fs: xfs
    db: mysql
  vol-yyyyyyy:
    path: /dev/mapper/ebs-othervolume
    fs: lvm

EOD
      exit(3)
    end
  end
end
