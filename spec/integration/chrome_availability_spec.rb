# frozen_string_literal: true

require 'spec_helper'
require 'net/http'
require 'json'

RSpec.describe 'Chrome Availability Check' do
  describe 'Chrome executable detection' do
    it 'can find a Chrome executable' do
      chrome_executables = ['google-chrome', 'chromium', 'chromium-browser', 'chrome']
      found_executable = nil
      
      chrome_executables.each do |executable|
        if system("which #{executable} > /dev/null 2>&1")
          found_executable = executable
          break
        end
      end

      if found_executable.nil?
        skip "No Chrome/Chromium executable found. Please install Chrome or Chromium to run integration tests."
      else
        expect(found_executable).not_to be_nil
        puts "Found Chrome executable: #{found_executable}"
      end
    end
  end

  describe 'Basic CDP connection test', :integration do
    let(:chrome_port) { 9222 }
    let(:chrome_pid) { nil }

    before do
      chrome_executables = ['google-chrome', 'chromium', 'chromium-browser', 'chrome']
      @chrome_executable = nil
      
      chrome_executables.each do |executable|
        if system("which #{executable} > /dev/null 2>&1")
          @chrome_executable = executable
          break
        end
      end

      skip "No Chrome executable found" if @chrome_executable.nil?

      @chrome_pid = start_chrome
      sleep(3) # Give Chrome time to start
    end

    after do
      stop_chrome(@chrome_pid) if @chrome_pid
    end

    it 'can start Chrome with CDP and list tabs' do
      # Test CDP endpoint
      begin
        response = Net::HTTP.get_response(URI("http://127.0.0.1:#{chrome_port}/json/list"))
        expect(response.code).to eq('200')
        
        tabs = JSON.parse(response.body)
        expect(tabs).to be_an(Array)
        expect(tabs).not_to be_empty
        
        tab = tabs.first
        expect(tab).to have_key('webSocketDebuggerUrl')
        expect(tab['webSocketDebuggerUrl']).to start_with('ws://')
        
        puts "Successfully connected to Chrome CDP on port #{chrome_port}"
        puts "Found #{tabs.length} tab(s)"
      rescue => e
        fail "Failed to connect to Chrome CDP: #{e.message}"
      end
    end

    private

    def start_chrome
      chrome_cmd = [
        @chrome_executable,
        '--headless=new',
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-extensions',
        '--disable-gpu',
        '--disable-software-rasterizer',
        '--remote-debugging-port=' + chrome_port.to_s,
        '--remote-debugging-address=127.0.0.1',
        'about:blank'
      ]

      begin
        pid = Process.spawn(*chrome_cmd, out: '/dev/null', err: '/dev/null')
        Process.detach(pid)
        pid
      rescue => e
        fail "Failed to start Chrome: #{e.message}"
      end
    end

    def stop_chrome(pid)
      return unless pid
      
      begin
        Process.kill('TERM', pid)
        sleep(1)
        Process.kill('KILL', pid) if process_exists?(pid)
      rescue Errno::ESRCH
        # Process already stopped
      end
    end

    def process_exists?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    end
  end
end