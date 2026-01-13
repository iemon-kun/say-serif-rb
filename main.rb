#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "mcp"

PROTOCOL_VERSION = "2024-11-05"
SERVER_NAME = "say-serif-rb"
SERVER_VERSION = "0.2.0"

DEFAULT_SPEED = 1.0
MIN_SPEED = 0.25
MAX_SPEED = 4.0
SAY_BASE_WPM = 175

SPEECH_CONCURRENCY_LIMIT = 1 # 同時再生を避け、音声が重なる混乱を防ぐため。
SPEECH_DEDUPE_WINDOW_SECONDS = 30.0 # 連打や重複要求で音声エンジンが詰まるのを防ぐため。
SAY_PROCESS_HARD_TIMEOUT_SECONDS = 300.0 # say が固着した場合の安全弁のため。

LOG_PATH = File.expand_path("tmp/boot.log", __dir__)

def log_debug(message)
  return unless ENV["SAY_SERIF_RB_DEBUG"] == "1"
  entry = "[say-serif-rb] #{message}"
  $stderr.puts(entry)
  FileUtils.mkdir_p(File.dirname(LOG_PATH))
  File.open(LOG_PATH, "a") { |f| f.puts(entry) }
rescue StandardError
  nil
end

class SpeechManager
  def initialize
    @mutex = Mutex.new
    @active = nil
    @recent = {}
  end

  def speak(text, speed: DEFAULT_SPEED)
    # 読み上げ品質が落ちないよう装飾記号を除去する。
    clean = strip_markdown(text.to_s)
    return "Text is empty." if clean.empty?
    return "Invalid speed (must be a positive number)." unless speed.is_a?(Numeric) && speed.positive?
    if speed < MIN_SPEED || speed > MAX_SPEED
      return "Invalid speed (supported range: #{MIN_SPEED}..#{MAX_SPEED})."
    end

    key = request_key(clean, speed)
    now = Time.now.to_f
    prune_recent_requests(now)

    @mutex.synchronize do
      if @active
        return "Speech already running." if @active[:key] == key
        return "Speech busy (concurrency limit #{SPEECH_CONCURRENCY_LIMIT})."
      end
      last = @recent[key]
      if last && (now - last) < SPEECH_DEDUPE_WINDOW_SECONDS
        return "Speech request deduped."
      end
      @recent[key] = now

      result = start_say_process(clean, speed)
      return result if result.is_a?(String)

      @active = { pid: result, key: key, started_at: now }
    end

    "Speech started (engine=say, mode=async, speed=#{format_speed(speed)}x, hard_timeout=#{SAY_PROCESS_HARD_TIMEOUT_SECONDS}s, dedupe=#{SPEECH_DEDUPE_WINDOW_SECONDS}s, concurrency=#{SPEECH_CONCURRENCY_LIMIT})"
  end

  def stop_speech
    pid = nil
    @mutex.synchronize do
      return "No active speech." unless @active
      pid = @active[:pid]
      @active = nil
    end
    terminate_say_process(pid)
    "Stopped speech (1)."
  end

  private

  def strip_markdown(text)
    stripped = text.dup
    stripped.gsub!(/(\*\*|__)(.*?)\1/, "\\2")
    stripped.gsub!(/(\*|_)(.*?)\1/, "\\2")
    stripped.gsub!(/\[([^\]]+)\]\([^)]+\)/, "\\1")
    stripped.gsub!(/`([^`]+)`/, "\\1")
    stripped.gsub!(/^>\s?/, "")
    stripped.gsub!(/^#+\s?/, "")
    stripped.strip
  end

  def request_key(text, speed)
    digest = Digest::SHA256.hexdigest(text)[0, 16]
    format("%.3f:%s", speed, digest)
  end

  def prune_recent_requests(now)
    cutoff = now - [SPEECH_DEDUPE_WINDOW_SECONDS * 2, 60.0].max
    @recent.delete_if { |_k, ts| ts < cutoff }
  end

  def start_say_process(text, speed)
    cmd = ["say"]
    if speed != DEFAULT_SPEED
      wpm = (SAY_BASE_WPM * speed).round
      wpm = [[wpm, 80].max, 600].min
      cmd += ["-r", wpm.to_s]
    end

    pid = Process.spawn(*cmd, text, out: "/dev/null", err: "/dev/null")
    monitor_say_process(pid)
    pid
  rescue Errno::ENOENT
    "Speech engine command not found."
  rescue Errno::EACCES
    "Speech engine is not executable."
  end

  def monitor_say_process(pid)
    Thread.new do
      start = Time.now.to_f
      loop do
        waited = Process.waitpid(pid, Process::WNOHANG)
        break if waited
        if (Time.now.to_f - start) >= SAY_PROCESS_HARD_TIMEOUT_SECONDS
          terminate_say_process(pid)
          Process.waitpid(pid) rescue nil
          break
        end
        sleep 0.1
      end
      @mutex.synchronize do
        @active = nil if @active && @active[:pid] == pid
      end
    end
  end

  def terminate_say_process(pid)
    Process.kill("TERM", pid)
    sleep 0.2
    Process.kill("KILL", pid)
  rescue Errno::ESRCH
    nil
  end

  def format_speed(speed)
    speed.round(3).to_s
  end
end

class SpeakTool < MCP::Tool
  tool_name "speak"
  description "macOSのsayでテキストを読み上げます（非同期）。"
  input_schema(
    properties: {
      text: { type: "string", description: "読み上げるテキスト。" },
      speed: { type: "number", description: "速度倍率（既定1.0）。" }
    },
    required: ["text"]
  )

  def self.call(text:, speed: nil, server_context:)
    manager = server_context[:speech]
    actual_speed = speed.nil? ? DEFAULT_SPEED : speed
    message = manager.speak(text, speed: actual_speed)
    MCP::Tool::Response.new([{ type: "text", text: message }])
  end
end

class StopSpeechTool < MCP::Tool
  tool_name "stop_speech"
  description "現在の読み上げを停止します（この実装は1件のみ）。"
  input_schema(properties: {})

  def self.call(server_context:)
    manager = server_context[:speech]
    message = manager.stop_speech
    MCP::Tool::Response.new([{ type: "text", text: message }])
  end
end

log_debug("start")

configuration = MCP::Configuration.new(protocol_version: PROTOCOL_VERSION)
server = MCP::Server.new(
  name: SERVER_NAME,
  version: SERVER_VERSION,
  tools: [SpeakTool, StopSpeechTool],
  server_context: { speech: SpeechManager.new },
  configuration: configuration
)

transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open
