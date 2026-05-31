require 'fileutils'

module PidManager
  STATE_DIR = File.expand_path('~/.local/state/forward-proxy')
  PID_FILE = File.join(STATE_DIR, 'forward-proxy.pid')

  def self.write
    FileUtils.mkdir_p(STATE_DIR)
    File.write(PID_FILE, Process.pid)
  end

  def self.read
    return nil unless File.exist?(PID_FILE)
    File.read(PID_FILE).strip.to_i
  rescue
    nil
  end

  def self.running?
    pid = read
    return false unless pid

    Process.kill(0, pid)
    true
  rescue Errno::ESRCH, Errno::ENOENT
    false
  end

  def self.remove
    File.delete(PID_FILE) if File.exist?(PID_FILE)
  rescue
    nil
  end

  def self.clear
    remove
  end
end
