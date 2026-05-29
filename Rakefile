require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"
  t.test_files = FileList["test/**/test_*.rb"]
end

desc "Run the Sinatra app on PORT (default 4567)"
task :server do
  exec "bundle exec rackup -p #{ENV.fetch('PORT', '4567')}"
end

task default: :test
