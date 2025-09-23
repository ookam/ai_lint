require "spec_helper"
require "fileutils"

RSpec.describe AiLint::CLI do
  let(:rule)    { "spec/fixtures/rule.md" }
  let(:engine)  { "claude" }
  let(:jobs)    { "2" }
  let(:file1)   { "spec/fixtures/file1.rb" }
  let(:file2)   { "spec/fixtures/file2.rb" }

  before do
    # ルールファイルのダミー
    FileUtils.mkdir_p(File.dirname(rule))
    File.write(rule, "# rule\n") unless File.exist?(rule)
    # テスト用の実在ファイル
    File.write(file1, "puts :ok\n") unless File.exist?(file1)
    File.write(file2, "puts :ng\n") unless File.exist?(file2)
    # デフォルトではエンジンは利用可能とみなす（個別テストで上書き）
    allow(AiLint::Engines::System).to receive(:available?).and_return(true)
  end

  it "requires -r, -a, -j and at least one file" do
    code, out = AiLint::CLI.run(%w[])
    expect(code).to eq(1)
    expect(out).to include("Usage:")
  end

  it "prints help with exit code 0" do
    code, out = AiLint::CLI.run(["--help"])
    expect(code).to eq(0)
    expect(out).to include("Usage:")
  end

  it "fails when any required option missing" do
    code, _ = AiLint::CLI.run(["-r", rule, "-a", engine])
    expect(code).to eq(1)

    code, _ = AiLint::CLI.run(["-r", rule, "-j", jobs])
    expect(code).to eq(1)

    code, _ = AiLint::CLI.run(["-a", engine, "-j", jobs])
    expect(code).to eq(1)
  end

  it "rejects invalid engine values" do
    code, out = AiLint::CLI.run(["-r", rule, "-a", "gpt4", "-j", jobs, "a.rb"])
    expect(code).to eq(1)
    expect(out).to match(/engine must be one of/i)
  end

  it "fails when rule file does not exist" do
    missing = "spec/fixtures/no_such_rule.md"
    File.delete(missing) if File.exist?(missing)
    code, out = AiLint::CLI.run(["-r", missing, "-a", engine, "-j", jobs, "a.rb"])
    expect(code).to eq(1)
    expect(out).to match(/rule file not found/i)
  end

  it "fails when any target file does not exist" do
    missing = "spec/fixtures/missing_x.rb"
    File.delete(missing) if File.exist?(missing)
    code, out = AiLint::CLI.run(["-r", rule, "-a", engine, "-j", jobs, missing])
    expect(code).to eq(1)
    expect(out).to match(/file not found/i)
    expect(out).to include(missing)
  end

  it "fails when engine command is not available" do
    # Systemエンジンのavailable?をスタブ
    allow(AiLint::Engines::System).to receive(:available?).with("claude").and_return(false)
    code, out = AiLint::CLI.run(["-r", rule, "-a", engine, "-j", jobs, file1])
    expect(code).to eq(1)
    expect(out).to match(/engine command not found/i)
  end

  describe "option validations" do
    it "accepts allowed engine names" do
      fake_runner = Class.new do
        def initialize(rule:, engine:, jobs:); end
        def run(files); [{ file: files.first, status: "ok", messages: [] }]; end
      end
      code, _ = AiLint::CLI.run(["-r", rule, "-a", "claude", "-j", jobs, file1], runner_class: fake_runner)
      expect(code).to eq(0)

      code, _ = AiLint::CLI.run(["-r", rule, "-a", "codex", "-j", jobs, file1], runner_class: fake_runner)
      expect(code).to eq(0)
    end

    it "rejects empty files list" do
      code, out = AiLint::CLI.run(["-r", rule, "-a", engine, "-j", jobs])
      expect(code).to eq(1)
      expect(out).to include("Usage:")
    end

    it "rejects non-integer jobs" do
      code, out = AiLint::CLI.run(["-r", rule, "-a", engine, "-j", "x", "a.rb"])
      expect(code).to eq(1)
      expect(out).to include("Usage:")
    end

    it "rejects jobs less than 1" do
      code, out = AiLint::CLI.run(["-r", rule, "-a", engine, "-j", "0", "a.rb"])
      expect(code).to eq(1)
      expect(out).to match(/jobs must be >= 1/i)
    end
  end

  it "accepts required options and one file; prints pass banner when ok" do
    fake_runner = Class.new do
      def initialize(rule:, engine:, jobs:)
      end
      def run(files)
        [{ file: files.first, status: "ok", messages: [] }]
      end
    end

    code, out = AiLint::CLI.run(["-r", rule, "-a", engine, "-j", jobs, "lib/ai_lint.rb"], runner_class: fake_runner)
    expect(code).to eq(0)
    expect(out).to include("AI Lint 通過")
  end

  it "prints failure banner and returns 1 when any ng" do
    fake_runner = Class.new do
      def initialize(rule:, engine:, jobs:)
      end
      def run(_files)
        [
          { file: "a.rb", status: "ok", messages: [] },
          { file: "b.rb", status: "ng", messages: ["bad"] }
        ]
      end
    end

    code, out = AiLint::CLI.run(["-r", rule, "-a", engine, "-j", jobs, file1, file2], runner_class: fake_runner)
    expect(code).to eq(1)
    expect(out).to include("AI Lint 失敗")
    expect(out).to include("b.rb")
  end

  it "prints engine error label when invalid response" do
    fake_runner = Class.new do
      def initialize(rule:, engine:, jobs:); end
      def run(_files)
        [ { file: "a.rb", status: "ng", messages: ["invalid response: JSON::ParserError: unexpected token"] } ]
      end
    end
    code, out = AiLint::CLI.run(["-r", rule, "-a", engine, "-j", jobs, file1], runner_class: fake_runner)
    expect(code).to eq(1)
    expect(out).to include("エンジンエラー")
    expect(out).to include("応答形式エラー")
    expect(out).to include("詳細:")
  end

  it "maps timeout message to friendly guidance" do
    fake_runner = Class.new do
      def initialize(rule:, engine:, jobs:); end
      def run(_files)
        [ { file: "a.rb", status: "ng", messages: ["engine timeout after 30s"] } ]
      end
    end
    code, out = AiLint::CLI.run(["-r", rule, "-a", engine, "-j", jobs, file1], runner_class: fake_runner)
    expect(code).to eq(1)
    expect(out).to include("エンジンエラー")
    expect(out).to include("タイムアウト")
    expect(out).to include("AI_LINT_TIMEOUT")
  end

  it "maps engine failed to actionable message" do
    fake_runner = Class.new do
      def initialize(rule:, engine:, jobs:); end
      def run(_files)
        [ { file: "a.rb", status: "ng", messages: ["engine failed: claude"] } ]
      end
    end
    code, out = AiLint::CLI.run(["-r", rule, "-a", engine, "-j", jobs, file1], runner_class: fake_runner)
    expect(code).to eq(1)
    expect(out).to include("エンジンエラー")
    expect(out).to include("エンジン実行エラー")
  end

  it "maps auth error to login guidance" do
    fake_runner = Class.new do
      def initialize(rule:, engine:, jobs:); end
      def run(_files)
        [ { file: "a.rb", status: "ng", messages: ["Invalid API key · Please run /login"] } ]
      end
    end
    code, out = AiLint::CLI.run(["-r", rule, "-a", engine, "-j", jobs, file1], runner_class: fake_runner)
    expect(code).to eq(1)
    expect(out).to include("エンジンエラー")
    expect(out).to include("認証エラー")
    expect(out).to include("/login")
  end
end
