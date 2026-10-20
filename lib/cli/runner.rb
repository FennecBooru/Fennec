# frozen_string_literal: true

module CLI
  # The bin/fennec entrypoint. Groups are found by loading everything in lib/cli, and commands can be given as
  # "group:command" or "group command"
  class Runner < Thor
    def self.exit_on_failure?
      true
    end

    def self.groups
      Rails.autoloaders.main.eager_load_dir(Rails.root.join("lib/cli"))
      CLI::Base.descendants.sort_by(&:group_name)
    end

    def self.start(argv = ARGV, config = {})
      groups.each do |group|
        desc("#{group.group_name}:COMMAND", group.summary)
        subcommand(group.group_name, group)
      end
      argv = argv.dup
      argv[0, 1] = argv[0].split(":", 2) if argv[0]&.match?(/\A[\w-]+:[\w-]+\z/)
      super
    end
  end
end
