require "spec_helper"

RSpec.describe AiLint::Engines::Codex do
  let(:rule_path) { "spec/fixtures/rule.md" }
  let(:file_path) { "spec/fixtures/file1.rb" }

  before do
    FileUtils.mkdir_p(File.dirname(rule_path))
    File.write(rule_path, "# rule\n") unless File.exist?(rule_path)
    File.write(file_path, "puts :ok\n") unless File.exist?(file_path)
  end

  it "calls System.command_for and executes with exec prompt including file" do
    require "open3"
    allow(AiLint::Engines::System).to receive(:command_for).with("codex").and_return("my-codex")

    out = { file: file_path, status: "ok", messages: [] }.to_json
    status = instance_double(Process::Status, success?: true)
    expect(Open3).to receive(:capture3) do |cmd, subcmd, prompt|
      expect(cmd).to eq("my-codex")
      expect(subcmd).to eq("exec")
      expect(prompt).to include("ファイル: #{file_path}")
      expect(prompt).to include('{"file":"' + file_path + '","status":"ok|ng","messages":["..."]}')
    end.and_return([out, "", status])

    codex = described_class.new(rule: rule_path)
    expect(codex.call(file_path)).to include(out)
  end

  it "prints debug raw output to stderr when AI_LINT_DEBUG set" do
    require "open3"
    allow(AiLint::Engines::System).to receive(:command_for).and_return("codex")
    out = "STDOUT"; err = "STDERR"
    begin
      ENV["AI_LINT_DEBUG"] = "1"
      expect(Open3).to receive(:capture3).and_return([out, err, instance_double(Process::Status, success?: true)])
      codex = described_class.new(rule: rule_path)
      expect { codex.call(file_path) }.to output(/raw stdout\+stderr/).to_stderr
    ensure
      ENV.delete("AI_LINT_DEBUG")
    end
  end
end
