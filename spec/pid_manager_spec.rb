require 'tmpdir'
require 'fileutils'
require_relative '../lib/pid_manager'

RSpec.describe PidManager do
  let(:tmpdir) { Dir.mktmpdir('pid_manager_spec') }
  let(:pid_file) { File.join(tmpdir, 'forward-proxy.pid') }

  before do
    stub_const('PidManager::STATE_DIR', tmpdir)
    stub_const('PidManager::PID_FILE', pid_file)
  end

  after do
    FileUtils.remove_entry(tmpdir) if tmpdir && Dir.exist?(tmpdir)
  end

  describe '.write' do
    it 'writes the current process PID to the PID file' do
      PidManager.write
      content = File.read(PidManager::PID_FILE)
      expect(content.strip.to_i).to eq(Process.pid)
    end

    it 'creates the state directory' do
      PidManager.write
      expect(Dir.exist?(PidManager::STATE_DIR)).to be true
    end
  end

  describe '.read' do
    it 'returns the PID from the file' do
      File.write(PidManager::PID_FILE, '12345')
      expect(PidManager.read).to eq(12345)
    end

    it 'returns nil when no PID file exists' do
      expect(PidManager.read).to be_nil
    end
  end

  describe '.running?' do
    it 'returns true when the PID is alive' do
      File.write(PidManager::PID_FILE, Process.pid.to_s)
      expect(PidManager.running?).to be true
    end

    it 'returns false when the PID file does not exist' do
      expect(PidManager.running?).to be false
    end

    it 'returns false when the PID is not alive' do
      File.write(PidManager::PID_FILE, '999999')
      expect(PidManager.running?).to be false
    end
  end

  describe '.remove' do
    it 'deletes the PID file' do
      File.write(PidManager::PID_FILE, '12345')
      PidManager.remove
      expect(File.exist?(PidManager::PID_FILE)).to be false
    end

    it 'does not raise when no PID file exists' do
      expect { PidManager.remove }.not_to raise_error
    end
  end
end
