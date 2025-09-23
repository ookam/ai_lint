require "spec_helper"

RSpec.describe AiLint::Runner do
  let(:rule)   { "spec/fixtures/rule.md" }
  let(:engine) { "claude" }

  before do
    FileUtils.mkdir_p(File.dirname(rule))
    File.write(rule, "# rule\n") unless File.exist?(rule)
  end

  it "forces status ng when messages are present even if ok" do
    fake_engine = Class.new do
      def initialize(rule:, engine:); end
      def call(_f)
        { file: "t.rb", status: "ok", messages: ["warn"] }.to_json
      end
    end
    r = described_class.new(rule: rule, engine: engine, jobs: 1, engine_class: fake_engine)
    res = r.run(["t.rb"]).first
    expect(res[:status]).to eq("ng")
  end

  it "emits debug to stderr when AI_LINT_DEBUG set" do
    fake_engine = Class.new do
      def initialize(rule:, engine:); end
      def call(_f); "{\"file\":\"t.rb\",\"status\":\"ok\",\"messages\":[]}"; end
    end
    begin
      ENV["AI_LINT_DEBUG"] = "1"
      r = described_class.new(rule: rule, engine: engine, jobs: 1, engine_class: fake_engine)
      expect { r.run(["t.rb"]) }.to output(/engine raw/).to_stderr
    ensure
      ENV.delete("AI_LINT_DEBUG")
    end
  end
end
