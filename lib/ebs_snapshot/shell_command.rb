require 'open4'
class ShellCommand

  attr_reader :pid, :stdout, :stderr, :status
  attr_accessor :command

  def initialize(cmd,timeout=4)
    @command = cmd
    @timeout = timeout
    @stderr = ''
    @stdout = ''
  end

  def spawn(parameters=nil)
    begin
      status = Open4.spawn("#{@command} #{parameters}", :stdin => '',
        :stdout => @stdout, :stderr => @stderr, :timeout => @timeout,
        :raise => false, :quiet => true
      )
      @status = status.exitstatus
      self.success?
    rescue Timeout::Error => e
      @stderr = e.message
      @status = -1
      self.success?
    end
  end

  def popen(parameters=nil)
    status = Open4::popen4("#{@command} #{parameters}") do
    |pid, stdin, stdout, stderr|
      @pid = pid
      @stdout = stdout.read.strip
      @stderr = stderr.read.strip
    end
    @status = status.exitstatus
    self.success?
  end

  def success?
    self.status == 0
  end

end
