require "open3"

module AiLint
  module Engines
    class Codex
      def initialize(rule:, engine: "codex")
        @rule_path = rule
        @cmd = AiLint::Engines::System.command_for(engine)
      end

      def call(file)
        rule = File.read(@rule_path)
        src  = File.read(file)
        prompt = <<~PROMPT
          あなたは厳密なJSONバリデータです。必ずJSONのみを出力し、前後に一切の文章を付けないでください。

          次の「ルール」はプロジェクトの規約のみを記述したものです（出力形式はここには書かれていません）。
          ルールが空や一般的なもので特に問題がない場合は、"status":"ok"、"messages":[] を返してください。

          ルール:
          #{rule}

          対象コード(ファイル: #{file}):
          #{src}

          返すJSONの形式（この形式のみ、例外なく厳守）:
          {"file":"#{file}","status":"ok|ng","messages":["..."]}
        PROMPT

        # Codex は `codex exec "..."` 形式で実行するのが一般的
        # ただし System.command_for で上書きされたコマンド名を尊重する
        stdout, stderr, status = Open3.capture3(@cmd, "exec", prompt)
        out = (stdout.to_s + stderr.to_s)
        if !status&.success? && out.strip.empty?
          out = { file: file, status: "ng", messages: ["engine failed: #{@cmd}"] }.to_json
        end
        if ENV["AI_LINT_DEBUG"]
          $stderr.puts "[ai_lint] raw stdout+stderr for #{file}:\n#{out}"
        end
        out
      end
    end
  end
end
