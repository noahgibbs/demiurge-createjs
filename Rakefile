require "bundler/gem_tasks"
require "rake/testtask"
require_relative "./lib/demiurge/createjs/version"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

file "dcjs/dcjs-combined.min.js" => Rake::FileList["dcjs/*.coffee", "vendor/*.js"] do
  sh "./node_modules/.bin/webpack --config dcjs/webpack.config.js"
end

task :package_js => "dcjs/dcjs-combined.min.js" do
  sh "cp dcjs/dcjs-combined.min.js dcjs/dcjs-v#{DCJS::VERSION}pre.min.js"
end

task :default => :test
