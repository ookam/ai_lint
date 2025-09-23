require "spec_helper"

RSpec.describe AiLint::Runner do
  let(:rule)   { "spec/fixtures/rule.md" }
  let(:engine) { "claude" }

  before do
    FileUtils.mkdir_p(File.dirname(rule))
    File.write(rule, "# rule\n") unless File.exist?(rule)
  end

  it "runs files in parallel according to jobs" do
    calls = Queue.new
    fake_engine = Class.new do
      def initialize(rule:, engine:); end
      def call(file)
        sleep 0.05
        { "file" => file, "status" => "ok", "messages" => [] }.to_json
      end
    end

    files = %w[a.rb b.rb c.rb d.rb e.rb]
    r = described_class.new(rule: rule, engine: engine, jobs: 2, engine_class: fake_engine)
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    results = r.run(files)
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    expect(results.size).to eq(files.size)
    # 単純逐次(0.25s)より速いことを期待(並列2なら ~0.13s 程度)
    expect(t1 - t0).to be < 0.2
  end
end
