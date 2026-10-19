# frozen_string_literal: true

# deploys run one of these, so log the version after them
%w[fixes:migrate_all fixes:migrate db:migrate].each do |name|
  next unless Rake::Task.task_defined?(name)
  Rake::Task[name].enhance { DeployTracker.version! }
end
