require "open3"
require "timeout"

module AiLint
  module Engines
    class System
      def self.command_for(engine)
        env_key = "AI_LINT_#{engine.upcase}_CMD"
        ENV[env_key].to_s.empty? ? engine : ENV[env_key]
      end

      def self.available?(engine)
        cmd = command_for(engine)
        return false if cmd.nil? || cmd.strip.empty?
        # Windows考慮は不要。Linux/mac向けにwhichでPATH探索
        system({ "PATH" => ENV["PATH"] }, "which", cmd, out: File::NULL, err: File::NULL)
      end
      def initialize(rule:, engine:)
        @rule = rule
        @engine = engine
      end

      def call(file)
        cmd = self.class.command_for(@engine)
        timeout_sec = (ENV["AI_LINT_TIMEOUT"].to_i > 0 ? ENV["AI_LINT_TIMEOUT"].to_i : 30)
        stdout = stderr = nil
        status = nil
        begin
          Timeout.timeout(timeout_sec) do
            stdout, stderr, status = Open3.capture3(cmd, "--rule", @rule, "--file", file)
          end
        rescue Timeout::Error
          return({ file: file, status: "ng", messages: ["engine timeout after #{timeout_sec}s"] }.to_json)
        end
        return stdout if status&.success?
        { file: file, status: "ng", messages: [
          "engine failed: #{cmd}",
          (stderr.to_s.strip.empty? ? nil : stderr.to_s.strip)
        ].compact }.to_json
      end

      private
    end
  end
end
