require 'AWS'
require 'shell_command'
require 'yaml'
require 'socket'

class EbsSnapshot
  VERSION = '0.0.2'
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
      path = args["path"]
      type = args["type"]
      case type
      when "mysql"
        mysql_snapshot(path,volume)
      when "file"
        file_snapshot(path,volume)
      else
        raise(StandardError, "Volume type #{type} not recognized")
      end
    end
  end
  
  def mysql_snapshot(path,volume)
    require 'sequel' unless Object.const_defined?('Sequel')
    begin
      mysql_connect unless mysql
      file, position = lock_mysql
      description = "#{hostname}:#{path} (#{file}, #{position})"
      snap = take_snapshot(path,volume,description)
      unlock_mysql
      snap['snapshotId']
    rescue StandardError => e
      unlock_mysql
      puts e.message
      exit(3)
    end
  end
  
  def file_snapshot(path,volume)
    begin
      description = "#{hostname}:#{path}"
      snap = take_snapshot(path,volume,description)
      snap['snapshotId']
    rescue StandardError => e
      puts e.message
      exit(3)
    end
  end

  protected
  
  def take_snapshot(path,volume,description)
    begin
      freeze_filesystem(path)
      snapshot = ec2.create_snapshot(
        :volume_id => volume, :description => description
      )
      thaw_filesystem(path)
      snapshot
    rescue StandardError => e
      thaw_filesystem(path)
      raise
    end
  end
  
  def freeze_filesystem(path)
    sync_command.popen
    raise(StandardError, freeze_cmd.stderr) unless freeze_cmd.popen(path)
  end
  
  def thaw_filesystem(path)
    raise(StandardError, thaw_cmd.stderr) unless thaw_cmd.popen(path)
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
  
  def freeze_cmd
    ShellCommand.new("/usr/sbin/xfs_freeze -f")
  end
  
  def unfreeze_cmd
    ShellCommand.new("/usr/sbin/xfs_freeze -u")
  end
  
  def sync_cmd
    ShellCommand.new("/bin/sync")
  end
  
  def ec2_connect
    @ec2 = AWS::EC2::Base.new(
      :access_key_id => config['aws']['access_key'],
      :secret_access_key => config['aws']['secret_key']
    )
  end
  
  def mysql_connect
    @mysql = Sequel.connect(
      config['mysql'].update(:single_threaded => true, :adapter => 'mysql')
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

# database authentication information
mysql:
  user: myuser
  password: mypassword

# set type to mysql if a mysql database volume
# set type to file if a regular filesystem
snapshots:
  vol-xxxxxxx:
    path: /mnt/dbvolume
    type: mysql
  vol-yyyyyyy:
    path: /mnt/othervolume
    type: file
\n\n
EOD
      exit(3)
    end
  end
end
