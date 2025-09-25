require "optparse"

module AiLint
  class CLI
    BANNER = <<~USAGE
      Usage:
        ai_lint -r RULE.md -a (claude|codex) -j NUM FILE [FILE...]
    USAGE

    def self.run(argv, runner_class: AiLint::Runner)
      options = { rule: nil, engine: nil, jobs: nil }
      files = []

      parser = OptionParser.new do |o|
        o.banner = BANNER
        o.on("-r", "--rule PATH", String, "ルール Markdown ファイル") { |v| options[:rule] = v }
        o.on("-a", "--ai ENGINE", String, "使用するAIエンジン") { |v| options[:engine] = v }
        o.on("-j", "--jobs NUM", Integer, "並列ジョブ数") { |v| options[:jobs] = v }
        o.on("-h", "--help", "ヘルプ") { return [0, o.to_s] }
      end

      begin
        # 引数を一旦すべて受け取り、後段でファイル/ディレクトリを振り分ける
        all_inputs = parser.parse(argv)
      rescue OptionParser::ParseError => e
        return [1, [BANNER, e.message].join("\n")]
      end

      # ディレクトリはスキップ対象。
      inputs = Array(all_inputs)
      skipped_dirs = inputs.select { |p| File.directory?(p) }
      non_dir_inputs = inputs - skipped_dirs
      # Runnerに渡すのは実在する通常ファイルのみ（後段で決定）。
      files = non_dir_inputs.select { |p| File.file?(p) }
      # 非ディレクトリ入力のうち、通常ファイルでないものは未知扱い
      unknown = non_dir_inputs - files

      # 必須チェックは「非ディレクトリの入力があるか」で判定（存在チェックは後段）。
      unless options[:rule] && options[:engine] && options[:jobs].is_a?(Integer) && non_dir_inputs.any?
        return [1, parser.to_s]
      end

      allowed = %w[claude codex]
      unless allowed.include?(options[:engine])
        return [1, "engine must be one of: #{allowed.join(', ')}"]
      end

      if options[:jobs].to_i < 1
        return [1, "jobs must be >= 1"]
      end

      unless File.exist?(options[:rule])
        return [1, "rule file not found: #{options[:rule]}"]
      end

      # 存在しない指定はエラー（ディレクトリは除外済み）
      missing = unknown.reject { |f| File.exist?(f) }
      unless missing.empty?
        return [1, "file not found: #{missing.join(', ')}"]
      end

      unless AiLint::Engines::System.available?(options[:engine])
        return [1, "engine command not found: #{AiLint::Engines::System.command_for(options[:engine])}"]
      end

      runner = runner_class.new(rule: options[:rule], engine: options[:engine], jobs: options[:jobs])
      results = runner.run(files)

  out_lines = []
      out_lines << "🚀 AI Lint を実行します"
      out_lines << "📊 ルールファイル: #{options[:rule]}"
      out_lines << "🤖 AIエンジン: #{options[:engine]}"
      out_lines << "📁 チェック対象ファイル数: #{files.length}"
      files.each_with_index { |f, i| out_lines << "   #{i + 1}. #{f}" }
  skipped_dirs.each { |d| out_lines << "⏭️ SKIP (directory): #{d}" }

      failed = false
      results.each do |res|
        if res[:status] == "ok"
          out_lines << "✅ #{res[:file]} に問題はありません"
        else
          failed = true
          msgs = Array(res[:messages]).map(&:to_s)
          engine_err = msgs.any? { |m| m =~ /(invalid response|engine failed|timeout|invalid api key|please run \/login)/i }
          if engine_err
            out_lines << "❌ エンジンエラー: #{res[:file]}"
            msgs = self.map_engine_messages(msgs, engine: options[:engine])
          else
            out_lines << "❌ #{res[:file]} に問題があります"
          end
          msgs.each { |m| out_lines << "   - #{m}" }
        end
      end

      if failed
        out_lines << "❌ AI Lint 失敗"
        [1, out_lines.join("\n")]
      else
        out_lines << "🎉 AI Lint 通過"
        [0, out_lines.join("\n")]
      end
    end

    class << self
      def map_engine_messages(msgs, engine: nil)
        msgs.flat_map do |s|
          str = s.to_s
          case str
          when /invalid api key|please run \/login/i
            [
              "認証エラー: エンジンへのログイン/認証が必要です（例: #{engine} でのログイン・APIキー設定）。",
              "詳細: #{str}"
            ]
          when /timeout/i
            [
              "タイムアウト: 規定時間内に応答がありません。環境変数 AI_LINT_TIMEOUT で延長可能です。",
              "詳細: #{str}"
            ]
          when /engine failed/i
            [
              "エンジン実行エラー: コマンド実行に失敗しました。コマンドやPATH、権限を確認してください。",
              "詳細: #{str}"
            ]
          when /invalid response/i
            [
              "応答形式エラー: AIエンジンの出力がJSONではありません。プロンプトやエンジン設定を確認してください。",
              "詳細: #{str}"
            ]
          else
            [str]
          end
        end
      end
    end
  end
end
