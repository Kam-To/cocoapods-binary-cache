require "rspec"
require "tmpdir"
require "fileutils"
require "pathname"
require "cocoapods"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
