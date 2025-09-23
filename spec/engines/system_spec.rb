require "spec_helper"

RSpec.describe AiLint::Engines::System do
  let(:rule)   { "spec/fixtures/rule.md" }
  let(:engine) { "claude" }
  let(:file)   { "app/models/user.rb" }

  before do
    FileUtils.mkdir_p(File.dirname(rule))
    File.write(rule, "# rule\n") unless File.exist?(rule)
  end

  it "invokes engine command with --rule and --file and returns stdout" do
    require "open3"
    out = { file: file, status: "ok", messages: [] }.to_json
    status = instance_double(Process::Status, success?: true)

    expect(Open3).to receive(:capture3).with("claude", "--rule", rule, "--file", file).and_return([out, "", status])

    sys = described_class.new(rule: rule, engine: engine)
    expect(sys.call(file)).to eq(out)
  end

  it "uses ENV override when available and still returns stdout" do
    require "open3"
    out = { file: file, status: "ok", messages: [] }.to_json
    status = instance_double(Process::Status, success?: true)
    begin
      ENV["AI_LINT_CLAUDE_CMD"] = "my-claude"
      expect(Open3).to receive(:capture3).with("my-claude", "--rule", rule, "--file", file).and_return([out, "err", status])

      sys = described_class.new(rule: rule, engine: engine)
      expect(sys.call(file)).to eq(out)
    ensure
      ENV.delete("AI_LINT_CLAUDE_CMD")
    end
  end

  it "returns ng json when command fails (non-zero)" do
    require "open3"
    status = instance_double(Process::Status, success?: false)
    expect(Open3).to receive(:capture3).and_return(["", "boom", status])
    sys = described_class.new(rule: rule, engine: engine)
    res = JSON.parse(sys.call(file))
    expect(res["status"]).to eq("ng")
    expect(res["messages"].join).to include("boom")
  end

  it "returns ng json on timeout" do
    require "open3"
    begin
      ENV["AI_LINT_TIMEOUT"] = "1"
      expect(Open3).to receive(:capture3) do
        sleep 2
      end
      sys = described_class.new(rule: rule, engine: engine)
      res = JSON.parse(sys.call(file))
      expect(res["status"]).to eq("ng")
      expect(res["messages"].join).to include("timeout")
    ensure
      ENV.delete("AI_LINT_TIMEOUT")
    end
  end
end
