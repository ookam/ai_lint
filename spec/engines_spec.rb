require "spec_helper"

RSpec.describe AiLint::Engines do
  it "maps claude to Engines::Claude" do
    expect(described_class.class_for("claude")).to eq(AiLint::Engines::Claude)
  end

  it "maps codex and others to Engines::System" do
    expect(described_class.class_for("codex")).to eq(AiLint::Engines::Codex)
    expect(described_class.class_for("unknown")).to eq(AiLint::Engines::System)
  end
end

RSpec.describe AiLint::Engines::System do
  it "command_for uses ENV override when set" do
    begin
      ENV["AI_LINT_CODEX_CMD"] = "codex-bin"
      expect(described_class.command_for("codex")).to eq("codex-bin")
    ensure
      ENV.delete("AI_LINT_CODEX_CMD")
    end
  end

  it "available? returns false for empty command" do
    allow(described_class).to receive(:command_for).and_return("")
    expect(described_class.available?("claude")).to be false
  end
end
