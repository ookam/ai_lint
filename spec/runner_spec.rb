require "spec_helper"

RSpec.describe AiLint::Runner do
  let(:rule)   { "spec/fixtures/rule.md" }
  let(:engine) { "claude" }
  let(:jobs)   { 2 }

  before do
    FileUtils.mkdir_p(File.dirname(rule))
    File.write(rule, "# rule\n") unless File.exist?(rule)
  end

  it "invokes engine for each file and collects ok results" do
    fake_engine = Class.new do
      def initialize(rule:, engine:)
      end
      def call(file)
        { "file" => file, "status" => "ok", "messages" => [] }.to_json
      end
    end

    r = described_class.new(rule: rule, engine: engine, jobs: jobs, engine_class: fake_engine)
    results = r.run(["a.rb", "b.rb"]).sort_by { |h| h[:file] }
    expect(results).to eq([
      { file: "a.rb", status: "ok", messages: [] },
      { file: "b.rb", status: "ok", messages: [] }
    ])
  end

  it "treats invalid JSON as ng with a message" do
    fake_engine = Class.new do
      def initialize(rule:, engine:)
      end
      def call(_file)
        "not json"
      end
    end

    r = described_class.new(rule: rule, engine: engine, jobs: 1, engine_class: fake_engine)
    results = r.run(["x.rb"])
    expect(results.first[:status]).to eq("ng")
    expect(results.first[:messages]).not_to be_empty
  end

  it "returns results in input file order" do
    fake_engine = Class.new do
      def initialize(rule:, engine:); end
      def call(file)
        { "file" => file, "status" => "ok", "messages" => [] }.to_json
      end
    end
    files = ["b.rb", "a.rb", "c.rb"]
    r = described_class.new(rule: rule, engine: engine, jobs: 2, engine_class: fake_engine)
    results = r.run(files)
    expect(results.map { |h| h[:file] }).to eq(files)
  end

  it "maps unexpected status to ng" do
    fake_engine = Class.new do
      def initialize(rule:, engine:); end
      def call(_)
        { "file" => "x.rb", "status" => "maybe", "messages" => [] }.to_json
      end
    end
    r = described_class.new(rule: rule, engine: engine, jobs: 1, engine_class: fake_engine)
    res = r.run(["x.rb"]).first
    expect(res[:status]).to eq("ng")
  end

  it "ignores engine-provided file field and uses input file" do
    fake_engine = Class.new do
      def initialize(rule:, engine:); end
      def call(_)
        { "file" => "engine.rb", "status" => "ok", "messages" => [] }.to_json
      end
    end
    r = described_class.new(rule: rule, engine: engine, jobs: 1, engine_class: fake_engine)
    res = r.run(["input.rb"]).first
    expect(res[:file]).to eq("input.rb")
  end
end
