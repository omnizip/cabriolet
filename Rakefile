# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "fileutils"

RuboCop::RakeTask.new

namespace :chm_fixtures do
  # Load centralized CHM fixture configuration
  require_relative "spec/support/fixture_chm"

  # Helper method to clone a git repository
  def clone_repo(name, url, target_path)
    require "fileutils"

    puts "[chm_fixtures:clone] Cloning #{name}..."

    # Remove existing directory if present
    FileUtils.rm_rf(target_path)

    # Clone the repository
    system("git", "clone", "--depth", "1", url, target_path)
    unless $?.success?
      raise "[chm_fixtures:clone] Failed to clone #{name} from #{url}"
    end

    puts "[chm_fixtures:clone] #{name} cloned successfully"
  end

  # Get repository configurations from centralized source
  repos = FixtureChm.rakefile_config

  # Create file tasks for each repository
  repos.each do |name, config|
    file config[:marker] do
      clone_repo(name, config[:repo], config[:repo_target])
    end
  end

  desc "Clone office_automation_dev repository with official Microsoft CHM files"
  task clone: repos.values.map { |config| config[:marker] }

  desc "Clean cloned CHM fixture repositories"
  task :clean do
    repos.each_value do |config|
      target = config[:repo_target]
      if File.exist?(target)
        puts "[chm_fixtures:clean] Removing #{target}..."
        FileUtils.rm_rf(target)
        puts "[chm_fixtures:clean] Removed #{target}"
      end
    end
  end

  desc "Run CHM tests against official Microsoft Office VBA documentation"
  task test: :clone do
    puts "[chm_fixtures:test] Running CHM tests with official Microsoft files..."

    # Run CHM specs
    require "rspec/core/rake_task"
    RSpec::Core::RakeTask.new(:chm_specs) do |t|
      t.pattern = "spec/chm/**/*_spec.rb"
      t.rspec_opts = "--format documentation --color"
    end

    Rake::Task[:chm_specs].invoke

    puts "[chm_fixtures:test] CHM tests completed"
  end

  desc "List all available CHM test files from cloned repositories"
  task :list do
    repos.each do |name, config|
      puts "\n#{name}:"
      puts "  Description: #{config[:description]}"
      puts "  Path: #{config[:repo_target]}"

      if FixtureChm.repo_cloned?(name)
        puts "  Status: Cloned"
        test_files = FixtureChm.all_test_files[name]
        puts "  Test files (#{test_files.length}):"
        test_files.each do |file|
          exists = File.exist?(file) ? "✓" : "✗"
          puts "    [#{exists}] #{File.basename(file)}"
        end
      else
        puts "  Status: Not cloned (run 'rake chm_fixtures:clone' to download)"
      end
    end
  end
end

# RSpec task
RSpec::Core::RakeTask.new(:spec)

# Default task runs spec and rubocop
task default: %i[spec rubocop]
