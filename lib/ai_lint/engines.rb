module AiLint
  module Engines
    def self.class_for(name)
      case name
      when "claude"
        AiLint::Engines::Claude
      when "codex"
        AiLint::Engines::Codex
      else
        AiLint::Engines::System
      end
    end
  end
end
