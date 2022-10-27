# frozen_string_literal: true

require_relative "imports"

OpenHAB::DSL.import_presets

require "openhab/log/logger"

# the order of these is important
require_relative "types/types"
require_relative "items/items"

require_relative "monkey_patch/ruby/ruby"
require_relative "monkey_patch/java/java"
require_relative "monkey_patch/events/events"
require_relative "monkey_patch/actions/actions"

require_relative "rules/rule"
require_relative "rules/terse"
require_relative "actions"
require_relative "channel"
require_relative "timers"
require_relative "group"
require_relative "things"
require_relative "between"
require_relative "gems"
require_relative "persistence"
require_relative "uid"
require_relative "units"
require_relative "states"
require_relative "openhab"

module OpenHAB
  #
  # Module to be extended to access the OpenHAB Ruby DSL
  #
  module DSL
    # Extend the calling module/class with the DSL
    # Disabling method length because they are all includes
    def self.extended(base)
      base.send :include, OpenHAB::DSL::Actions
      base.send :include, OpenHAB::DSL::Between
      base.send :include, OpenHAB::DSL::Core
      base.send :include, OpenHAB::DSL::Groups
      base.send :include, OpenHAB::DSL::Items
      base.send :include, OpenHAB::DSL::Persistence
      base.send :include, OpenHAB::DSL::Rules::Rule
      base.send :include, OpenHAB::DSL::Rules::TerseRule
      base.send :include, OpenHAB::DSL::States
      base.send :include, OpenHAB::DSL::Things
      base.send :include, OpenHAB::DSL::Timers
      base.send :include, OpenHAB::DSL::Between
      base.send :include, OpenHAB::DSL::Types
      base.send :include, OpenHAB::DSL::Units
    end
  end
end
