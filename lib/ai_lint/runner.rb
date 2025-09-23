require "json"
require_relative "json_extract"
require_relative "engines"
require_relative "engines/claude"

module AiLint
  class Runner
    def initialize(rule:, engine:, jobs:, engine_class: nil)
      @rule = rule
      @engine = engine
      @jobs = jobs
      @engine_class = engine_class || AiLint::Engines.class_for(engine)
    end

    def run(files)
      queue = Queue.new
      files.each { |f| queue << f }
      results = []
      mutex = Mutex.new

      workers = Array.new(@jobs) do
        Thread.new do
          engine = @engine_class.new(rule: @rule, engine: @engine)
          while (file = (queue.pop(true) rescue nil))
            res = process_file(engine, file)
            mutex.synchronize { results << res }
          end
        end
      end

      workers.each(&:join)
      order = files.each_with_index.to_h
      results.sort_by { |h| order[h[:file]] || order[h[:file].to_s] || 1_000_000 }
    end

    private

    def process_file(engine, file)
      raw = engine.call(file)
      $stderr.puts "[ai_lint] engine raw for #{file}:\n#{raw}" if ENV["AI_LINT_DEBUG"]
      parsed = parse_response(raw)
  file_path = file
      messages = parsed["messages"] || []
  status = parsed["status"]
  status = "ng" unless %w[ok ng].include?(status)
      status = "ng" if status == "ok" && !messages.empty?
      { file: file_path, status: status, messages: messages }
    rescue => e
      { file: file, status: "ng", messages: ["invalid response: #{e.class}: #{e.message}"] }
    end

    def parse_response(raw)
      JSON.parse(raw)
    rescue JSON::ParserError
      extracted = AiLint::JSONExtract.from_output(raw)
      raise if extracted.nil?
      JSON.parse(extracted)
    end
  end
end
