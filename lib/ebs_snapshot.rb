require 'EC2'
require 'shell_command'
require 'yaml'

class EbsSnapshot
  VERSION = '0.0.1'
  attr_reader :config
  def self.snapshot
    ebs = EbsSnapshot.new
    ebs.snapshot
  end
  def initialize
    check_config
    @config = YAML::load(File.open('/etc/ebs_snapshot.yml'))
    @suspend = ShellCommand.new("/sbin/dmsetup suspend")
    @resume  = ShellCommand.new("/sbin/dmsetup resume")
    ec2_connect
  end
  def snapshot
    self.config['snapshots'].each do |snapshot|
      if snapshot['db']
        self.db_snapshot(snapshot)
      else
        self.fs_snapshot(snapshot)
      end
    end
  end
  def db_snapshot(snapshot)
    require 'sequel' unless Object.const_defined?('Sequel')
    begin
      db_connect
      master_status = lock_db
      snap_out = take_snapshot(snapshot['device'],snapshot['volume'])
      unlock_db
      output = {
        :status => "OK",
        :time => Time.now,
        :snapshot => snap_out["snapshotId"],
        :device => snapshot['device'],
        :volume => snapshot['volume'],
        :master_file => master_status[:File],
        :master_pos => master_status[:Position]
      }
      puts output.inspect
    rescue StandardError => e
      output = {
        :status => "ERROR",
        :time => Time.now,
        :error => e.class,
        :message => e.message,
        :backtrace => e.backtrace
      }
      puts output.inspect
      exit(3)
    end
  end
  def fs_snapshot(snapshot)
    begin
      snap_out = take_snapshot(snapshot['device'],snapshot['volume'])
      output = {
        :status => "OK",
        :time => Time.now,
        :snapshot => snap_out["snapshotId"],
        :device => snapshot['device'],
        :volume => snapshot['volume']
      }
    rescue StandardError => e
      output = {
        :status => "ERROR",
        :error => e.class,
        :message => e.message,
        :backtrace => e.backtrace
      }
      puts output.inspect
      exit(3)
    end
  end
  def ec2_connect
    @ec2 = EC2::Base.new(
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
  def take_snapshot(device,volume)
    begin
      suspend_device(device)
      snapshot = @ec2.create_snapshot(:volume_id => volume)
      resume_device(device)
      snapshot
    rescue StandardError => e
      resume_device(device)
      raise e
    end
  end
  def suspend_device(device)
    raise(StandardError, @suspend.stderr) unless @suspend.popen(device)
  end
  def resume_device(device)
    raise(StandardError, @resume.stderr) unless @resume.popen(device)
  end
  def lock_db
    @db['FLUSH TABLES WITH READ LOCK'].first
    @db['SHOW MASTER STATUS'].first
  end
  def unlock_db
    @db['UNLOCK TABLES'].first
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
  - device: /dev/mapper/voltest
    volume: vol-xxxxxxx
    db: true
  - device: /dev/mapper/voltest2
    volume: vol-xxxxxxx
\n\n
EOD
      exit(3)
    end
  end
end
