# frozen_string_literal: true

# Centralized CHM fixture configuration
# This is the single source of truth for CHM fixture paths and repository configuration.
# Includes official Microsoft CHM files from office_automation_dev repository.

module FixtureChm
  FIXTURES_BASE = File.expand_path(File.join(__dir__, "..", "fixtures"))

  # CHM fixture configuration
  # Each fixture has:
  # - repo: Git repository URL
  # - repo_target: Where to clone the repository (relative to FIXTURES_BASE)
  # - marker_file: File that must exist to consider the repo cloned
  # - test_files: Array of CHM files to test from this repo
  # - description: Human-readable description
  REPOS = {
    "office_automation_dev" => {
      repo: "https://github.com/pengwk/office_automation_dev",
      repo_target: "office_automation_dev",
      marker_file: "office_automation_dev/README.md",
      test_files: [
        # Excel 2013 Developer Documentation
        "Excel 2013 Developer Documentation.chm",
        # Word 2013 Developer Documentation
        "Word 2013 Developer Documentation.chm",
        "WDVBACon.chm",
        # PowerPoint 2013 Developer Documentation
        "PowerPoint 2013 Developer Documentation.chm",
        # Outlook 2013 Developer Documentation
        "Outlook 2013 Developer Documentation.chm",
        # Office Shared 2013 Developer Documentation
        "Office Shared 2013 Developer Documentation.chm",
        # Additional Office applications
        "Access 2013 Developer Documentation.chm",
        "OneNote 2013 Developer Documentation.chm",
        "Publisher 2013 Developer Documentation.chm",
        "Visio 2013 Developer Documentation.chm",
      ],
      description: "Official Microsoft Office VBA documentation CHM files",
    }.freeze,
  }.freeze

  # Get absolute path to the cloned repository
  # @param repo_name [String] Repository name (e.g., "office_automation_dev")
  # @return [String] Absolute path to the cloned repository
  def self.repo_path(repo_name)
    config = REPOS[repo_name]
    raise ArgumentError, "Unknown repository: #{repo_name}" unless config

    File.join(FIXTURES_BASE, config[:repo_target])
  end

  # Get absolute path to a specific CHM file in a repository
  # @param repo_name [String] Repository name (e.g., "office_automation_dev")
  # @param relative_path [String] Relative path within the repo (e.g., "Excel/API/ExcelVBA.chm")
  # @return [String] Absolute path to the CHM file
  def self.chm_path(repo_name, relative_path)
    File.join(repo_path(repo_name), relative_path)
  end

  # Get all CHM test files from all repositories
  # @return [Hash] Hash mapping repo_name to array of absolute CHM file paths
  def self.all_test_files
    result = {}
    REPOS.each do |name, config|
      result[name] = config[:test_files].map do |relative_path|
        chm_path(name, relative_path)
      end
    end
    result
  end

  # Get all required marker files (for checking if repos are cloned)
  # @return [Array<String>] Array of absolute paths to marker files
  def self.required_markers
    REPOS.map do |_name, config|
      File.join(FIXTURES_BASE, config[:marker_file])
    end
  end

  # Get Rakefile-compatible repository configuration
  # @return [Hash] Hash suitable for Rakefile clone tasks
  def self.rakefile_config
    REPOS.transform_values do |config|
      {
        repo: config[:repo],
        repo_target: File.join(FIXTURES_BASE, config[:repo_target]),
        marker: File.join(FIXTURES_BASE, config[:marker_file]),
        description: config[:description],
      }
    end
  end

  # Check if a repository is cloned
  # @param repo_name [String] Repository name
  # @return [Boolean] true if marker file exists
  def self.repo_cloned?(repo_name)
    File.exist?(File.join(FIXTURES_BASE, REPOS[repo_name][:marker_file]))
  end
end
