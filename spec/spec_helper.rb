require "rspec"
require_relative "../lib/ai_lint"

RSpec.configure do |config|
  config.order = :random
  Kernel.srand config.seed
end
