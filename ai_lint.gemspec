Gem::Specification.new do |spec|
  spec.name          = "ai_lint"
  spec.version       = "0.0.3"
  spec.authors       = ["you"]
  spec.email         = ["you@example.com"]

  spec.summary       = "AIによるコードレビューCLI"
  spec.description   = "Markdownルールと外部AI CLIを使って並列にレビューするシンプルなCLI"
  spec.homepage      = "https://example.com/ai_lint"
  spec.license       = "MIT"

  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*", "README.md", "exe/*"]
  end

  # Executables are located under exe/, not the default bin/
  spec.bindir        = "exe"
  spec.executables   = ["ai_lint"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.13"
end
