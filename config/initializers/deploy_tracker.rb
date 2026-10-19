# frozen_string_literal: true

# see DeployTracker
module DeployTracking
  module Migration
    def migrate(direction)
      super.tap { DeployTracker.migration!(self, direction) }
    end
  end

  module FixTracker
    def run!(path)
      super.tap { |name| DeployTracker.fix!(name) }
    end
  end
end

ActiveRecord::Migration.prepend(DeployTracking::Migration)
YiffSpace::FixTracker.singleton_class.prepend(DeployTracking::FixTracker)
