require "ebs_snapshot/version"
require "ebs_snapshot/shell_command"
require "AWS"
require "socket"

module EbsSnapshot

  class Base

    attr_reader :volume, :mysql, :aws, :hostname, :db

    def initialize(args={})
      @volume   = Volume.new(args[:volume])
      @mysql    = Mysql.new(args[:mysql]) if args[:mysql]
      @aws      = Aws.new(args[:aws])
      @hostname = args[:hostname] || Socket.gethostname
      @db       = args[:db] ? args[:db].to_sym : nil
    end

    def snapshot
      (db == :mysql) ? mysql_snapshot : file_snapshot
    end

    def mysql_snapshot
      require 'mysql2'
      begin
        file, position = mysql.lock
        description = "#{hostname}:#{volume.path} (#{file}, #{position})"
        volume.freeze
        aws.snapshot(volume.volume_id, description)
      rescue StandardError => e
        puts "ERROR: #{e.message}"
        raise
      ensure
        volume.thaw
        mysql.unlock
      end
    end

    def file_snapshot
      begin
        description = "#{hostname}:#{volume.path}"
        volume.freeze
        aws.snapshot(volume.volume_id, description)
      rescue StandardError => e
        puts "ERROR: #{e.message}"
        raise
      ensure
        volume.thaw
      end
    end

  end

  class Volume

    attr_reader :volume_id, :path, :filesystem

    def initialize(args={})
      @volume_id  = args[:volume_id]
      @filesystem = args[:filesystem] ? args[:filesystem].to_sym : nil
      @path       = args[:path]
      check_config
    end

    def freeze?
      filesystem == :xfs || :lvm
    end

    def freeze
      return unless freeze?
      sync = ShellCommand.new("/bin/sync")
      raise(StandardError, sync.stderr) unless sync.popen
      command = ShellCommand.new(freeze_command)
      raise(StandardError, command.stderr) unless command.popen(path)
    end

    def thaw
      return unless freeze?
      command = ShellCommand.new(thaw_command)
      raise(StandardError, command.stderr) unless command.popen(path)
    end

    protected

    def freeze_command
      case filesystem
      when :xfs
        "/usr/sbin/xfs_freeze -f"
      when :lvm
        "/sbin/dmsetup suspend"
      end
    end

    def thaw_command
      case filesystem
      when :xfs
        "/usr/sbin/xfs_freeze -u"
      when :lvm
        "/sbin/dmsetup resume"
      end
    end

    def check_config
      raise(StandardError, "VolumeID and Path are required") unless volume_id && path
      raise(StandardError, "Path #{path} does not exist") unless File.exists?(path)
    end

  end

  class Mysql

    attr_reader :username, :password, :host, :port

    def initialize(args={})
      @username = args[:username]
      @password = args[:password]
      @host     = args[:host] || '127.0.0.1'
      @port     = args[:port] || 3306
    end

    def connection
      @db ||= Mysql2::Client.new(
        :username => username, :password => password, :host => host, :port => port, :reconnect => true
      )
    end

    def lock
      connection.query('FLUSH TABLES WITH READ LOCK')
      status = connection.query('SHOW MASTER STATUS').first
      status ? [status['File'], status['Position']] : ['empty','empty']
    end

    def unlock
      connection.query('UNLOCK TABLES')
    end

  end

  class Aws

    attr_reader :access_key, :secret_key

    def initialize(args={})
      @access_key = args[:access_key] || ENV['AMAZON_ACCESS_KEY_ID']
      @secret_key = args[:secret_key] || ENV['AMAZON_SECRET_ACCESS_KEY']
    end

    def connection
      @aws ||= ::AWS::EC2::Base.new(
        :access_key_id => access_key, :secret_access_key => secret_key
      )
    end

    def snapshot(volume_id,description)
      connection.create_snapshot(:volume_id => volume_id, :description => description)
    end

  end

end
