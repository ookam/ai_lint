require "spec_helper"

RSpec.describe AiLint::JSONExtract do
  it "extracts json inside fenced block" do
    out = <<~TXT
      blah
      ```json
      {"file":"a.rb","status":"ok","messages":[]}
      ```
    TXT
    expect(described_class.from_output(out)).to include('"file":"a.rb"')
  end

  it "extracts json on a single line" do
    out = '{"file":"b.rb","status":"ok","messages":[]}'
    expect(described_class.from_output(out)).to include('"file":"b.rb"')
  end

  it "extracts balanced json from noisy output" do
    out = "noise {\"file\":\"x.rb\",\"status\":\"ok\",\"messages\":[]} tail"
    expect(described_class.from_output(out)).to include('"file":"x.rb"')
  end

  it "returns nil when nothing valid" do
    expect(described_class.from_output("oops")).to be_nil
  end
end
