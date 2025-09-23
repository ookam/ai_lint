require "spec_helper"

RSpec.describe AiLint::Runner do
  let(:rule)   { "spec/fixtures/rule.md" }
  let(:engine) { "claude" }

  before do
    FileUtils.mkdir_p(File.dirname(rule))
    File.write(rule, "# rule\n") unless File.exist?(rule)
  end

  it "parses fenced json output when engine adds prose" do
    fake_engine = Class.new do
      def initialize(rule:, engine:); end
      def call(_file)
        <<~OUT
          Note: something
          ```json
          {"file":"z.rb","status":"ok","messages":[]}
          ```
          trailing
        OUT
      end
    end
    r = described_class.new(rule: rule, engine: engine, jobs: 1, engine_class: fake_engine)
  res = r.run(["x.rb"]).first
  expect(res[:file]).to eq("x.rb")
    expect(res[:status]).to eq("ok")
  end

  it "falls back to balanced json when mixed output" do
    fake_engine = Class.new do
      def initialize(rule:, engine:); end
      def call(_)
        "noise {\"file\":\"x.rb\",\"status\":\"ng\",\"messages\":[\"m\"]} tail"
      end
    end
    r = described_class.new(rule: rule, engine: engine, jobs: 1, engine_class: fake_engine)
    res = r.run(["x.rb"]).first
    expect(res[:status]).to eq("ng")
    expect(res[:messages]).to eq(["m"])
  end

  it "ignores example json then uses real json on next line" do
    fake_engine = Class.new do
      def initialize(rule:, engine:); end
      def call(_)
        <<~OUT
          返すJSONの形式:
          {"file":".all_lint.yml","status":"ok|ng","messages":["..."]}
          実際の応答:
          {"file":".all_lint.yml","status":"ok","messages":[]}
        OUT
      end
    end
    r = described_class.new(rule: rule, engine: engine, jobs: 1, engine_class: fake_engine)
    res = r.run([".all_lint.yml"]).first
    expect(res[:status]).to eq("ok")
    expect(res[:messages]).to eq([])
  end
end
