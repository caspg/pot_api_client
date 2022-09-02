# frozen_string_literal: true

require "bundler/gem_tasks"
require "rubocop/rake_task"
require_relative "lib/pot_api_client"

RuboCop::RakeTask.new

task default: :rubocop

task :console do
  exec "irb -I lib -r ./lib/pot_api_client.rb"
end

task :fetch_and_save_attractions do
  PotApiClient.fetch_and_save_attractions
end
