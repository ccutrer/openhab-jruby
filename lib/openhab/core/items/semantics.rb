# frozen_string_literal: true

require "forwardable"

require_relative "generic_item"
require_relative "group_item"
require_relative "semantics/enumerable"

module OpenHAB
  module Core
    module Items
      # Module for implementing semantics helper methods on {Item} in order to easily navigate
      # the {https://www.openhab.org/docs/tutorial/model.html Semantic Model} in your scripts.
      # This can be extremely useful to find related items in rules that are executed for any member of a group.
      #
      # Wraps {org.openhab.core.model.script.actions.Semantics} as well as adding a few additional convenience methods.
      # Also includes classes for each semantic tag.
      #
      # Be warned that the Semantic model is stricter than can actually be
      # described by tags and groups on an Item. It makes assumptions that any
      # given item only belongs to one semantic type ({Location}, {Equipment}, {Point}).
      #
      # ## Enumerable helper methods
      #
      # {Enumerable Enumerable helper methods} are also provided to complement the semantic model. These methods can be
      # chained together to find specific item(s) based on custom tags or group memberships that are outside
      # the semantic model.
      #
      # The Enumerable helper methods apply to:
      #
      # * {GroupItem#members} and {GroupItem#all_members}. This includes semantic
      #   {#location} and {#equipment} because they are also group items.
      #   An exception is for Equipments that are an item (not a group)
      # * Array of items, such as the return value of {Enumerable#equipments}, {Enumerable#locations},
      #   {Enumerable#points}, {Enumerable#tagged}, {Enumerable#not_tagged}, {Enumerable#member_of},
      #   {Enumerable#not_member_of}, {Enumerable#members} methods, etc.
      # * {OpenHAB::DSL.items items[]} hash which contains all items in the system.
      #
      # ## Semantic Classes
      #
      # Each [Semantic
      # Tag](https://github.com/openhab/openhab-core/blob/main/bundles/org.openhab.core.semantics/model/SemanticTags.csv)
      # has a corresponding class within the {org.openhab.core.semantics} class hierarchy.
      # These "semantic classes" are available as constants in the {Semantics} module with the corresponding name.
      # The following table illustrates the semantic constants:
      #
      # | Semantic Constant       | openHAB's Semantic Class                               |
      # | ----------------------- | ------------------------------------------------------ |
      # | `Semantics::LivingRoom` | `org.openhab.core.semantics.model.location.LivingRoom` |
      # | `Semantics::Lightbulb`  | `org.openhab.core.semantics.model.equipment.Lightbulb` |
      # | `Semantics::Control`    | `org.openhab.core.semantics.model.point.Control`       |
      # | `Semantics::Switch`     | `org.openhab.core.semantics.model.point.Switch`        |
      # | `Semantics::Power`      | `org.openhab.core.semantics.model.property.Power`      |
      # | ...                     | ...                                                    |
      #
      # These constants can be used as arguments to the {#points},
      # {Enumerable#locations} and {Enumerable#equipments} methods to filter
      # their results. They can also be compared against the return value of
      # {#semantic_type}, {#location_type}, {#equipment_type}, {#point_type},
      # and {#property_type}. They can even be used with
      # {DSL::Items::ItemBuilder#tag}.
      #
      # The semantic constants in the `Semantics` module are enhanced with {TagClassMethods}
      # to provide easy access to the tags' additional attributes: {TagClassMethods.label label},
      # {TagClassMethods.synonyms synonyms}, and {TagClassMethods.description description}.
      # For example, to get the synonyms for `Semantics::Lightbulb` in German:
      # `Semantics::Lightbulb.synonyms(java.util.Locale::GERMAN)`
      #
      # @see https://github.com/openhab/openhab-core/blob/main/bundles/org.openhab.core.semantics/model/SemanticTags.csv Semantic Tags Table
      #
      # @example Working with tags
      #   # Return an array of sibling points with a "Switch" tag
      #   Light_Color.points(Semantics::Switch)
      #
      #   # check semantic type
      #   LoungeRoom_Light.equipment_type == Semantics::Lightbulb
      #   Light_Color.property_type == Semantics::Light
      #
      # @example switches.items
      #   Group   gFullOn
      #   Group   gRoomOff
      #
      #   Group   eGarageLights        "Garage Lights"             (lGarage)                 [ "Lightbulb" ]
      #   Dimmer  GarageLights_Dimmer  "Garage Lights"    <light>  (eGarageLights)           [ "Switch" ]
      #   Number  GarageLights_Scene   "Scene"                     (eGarageLights, gFullOn, gRoomOff)
      #
      #   Group   eMudLights           "Mud Room Lights"           (lMud)                    [ "Lightbulb" ]
      #   Dimmer  MudLights_Dimmer     "Garage Lights"    <light>  (eMudLights)              [ "Switch" ]
      #   Number  MudLights_Scene      "Scene"                     (eMudLights, gFullOn, gRoomOff)
      #
      # @example Find the switch item for a scene channel on a zwave dimmer
      #   rule "turn dimmer to full on when switch double-tapped up" do
      #     changed gFullOn.members, to: 1.3
      #     run do |event|
      #       dimmer_item = event.item.points(Semantics::Switch).first
      #       dimmer_item.ensure << 100
      #     end
      #   end
      #
      # @example Turn off all the lights in a room
      #   rule "turn off all lights in the room when switch double-tapped down" do
      #     changed gRoomOff.members, to: 2.3
      #     run do |event|
      #       event
      #         .item
      #         .location
      #         .equipments(Semantics::Lightbulb)
      #         .members
      #         .points(Semantics::Switch)
      #         .ensure.off
      #     end
      #   end
      #
      # @example Finding a related item that doesn't fit in the semantic model
      #   # We can use custom tags to identify certain items that don't quite fit in the semantic model.
      #   # The extensions to the Enumerable mentioned above can help in this scenario.
      #
      #   # In the following example, the TV `Equipment` has three `Points`. However, we are using custom tags
      #   # `Application` and `Channel` to identify the corresponding points, since the semantic model
      #   # doesn't have a specific property for them.
      #
      #   # Here, we use Enumerable#tagged
      #   # to find the point with the custom tag that we want.
      #
      #   # Item model:
      #   Group   gTVPower
      #   Group   lLivingRoom                                 [ "LivingRoom" ]
      #
      #   Group   eTV             "TV"       (lLivingRoom)    [ "Television" ]
      #   Switch  TV_Power        "Power"    (eTV, gTVPower)  [ "Switch", "Power" ]
      #   String  TV_Application  "App"      (eTV)            [ "Control", "Application" ]
      #   String  TV_Channel      "Channel"  (eTV)            [ "Control", "Channel" ]
      #
      #   # Rule:
      #   rule 'Switch TV to Netflix on startup' do
      #     changed gTVPower.members, to: ON
      #     run do |event|
      #       application = event.item.points.tagged('Application').first
      #       application << 'netflix'
      #     end
      #   end
      #
      # @example Find all semantic entities regardless of hierarchy
      #   # All locations
      #   items.locations
      #
      #   # All rooms
      #   items.locations(Semantics::Room)
      #
      #   # All equipments
      #   items.equipments
      #
      #   # All lightbulbs
      #   items.equipments(Semantics::Lightbulb)
      #
      #   # All blinds
      #   items.equipments(Semantics::Blinds)
      #
      #   # Turn off all "Power control"
      #   items.points(Semantics::Control, Semantics::Power).off
      #
      #   # All items tagged "SmartLightControl"
      #   items.tagged("SmartLightControl")
      #
      # ## Adding Custom Semantic Tags
      #
      # openHAB 4 supports adding custom semantic tags to augment the standard set of tags to better suit
      # your particular requirements.
      #
      # For more information, see {add}
      #
      module Semantics
        GenericItem.include(self)
        GroupItem.extend(Forwardable)
        GroupItem.def_delegators :members, :equipments, :locations

        # @!parse
        #   class Items::GroupItem
        #     #
        #     # @!attribute [r] equipments
        #     #
        #     # Calls {Enumerable#equipments members.equipments}.
        #     #
        #     # @return (see Enumerable#equipments)
        #     #
        #     # @see Enumerable#equipments
        #     #
        #     def equipments; end
        #
        #     #
        #     # @!attribute [r] locations
        #     #
        #     # Calls {Enumerable#locations members.locations}.
        #     #
        #     # @return (see Enumerable#locations)
        #     #
        #     # @see Enumerable#locations
        #     #
        #     def locations; end
        #   end
        #

        # This is a marker interface for all semantic tag classes.
        # @interface
        Tag = org.openhab.core.semantics.Tag

        # @!parse
        #   # This is the super interface for all types that represent a Location.
        #   # @interface
        #   Location = org.openhab.core.semantics.Location
        #
        #   # This is the super interface for all types that represent an Equipment.
        #   # @interface
        #   Equipment = org.openhab.core.semantics.Equipment
        #
        #   # This is the super interface for all types that represent a Point.
        #   # @interface
        #   Point = org.openhab.core.semantics.Point
        #
        #   # This is the super interface for all property tags.
        #   # @interface
        #   Property = org.openhab.core.semantics.Property

        # put ourself into the global namespace, replacing the action
        Object.send(:remove_const, :Semantics)
        ::Semantics = self # rubocop:disable Naming/ConstantName

        #
        # Checks if this Item is a {Location}
        #
        # This is implemented as checking if the item's {#semantic_type}
        # is a {Location}. I.e. an Item has a single {#semantic_type}.
        #
        # @return [true, false]
        #
        def location?
          Actions::Semantics.location?(self)
        end

        #
        # Checks if this Item is an {Equipment}
        #
        # This is implemented as checking if the item's {#semantic_type}
        # is an {Equipment}. I.e. an Item has a single {#semantic_type}.
        #
        # @return [true, false]
        #
        def equipment?
          Actions::Semantics.equipment?(self)
        end

        # Checks if this Item is a {Point}
        #
        # This is implemented as checking if the item's {#semantic_type}
        # is a {Point}. I.e. an Item has a single {#semantic_type}.
        #
        # @return [true, false]
        #
        def point?
          Actions::Semantics.point?(self)
        end

        #
        # Checks if this Item has any semantic tags
        #
        # @return [true, false]
        #
        def semantic?
          !!semantic_type
        end

        #
        # @!attribute [r] location
        #
        # Gets the related {Location} Item of this Item.
        #
        # Checks ancestor groups one level at a time, returning the first
        # {Location} Item found.
        #
        # @return [Item, nil]
        #
        def location
          Actions::Semantics.get_location(self)&.then(&Proxy.method(:new))
        end

        #
        # @!attribute [r] location_type
        #
        # Returns the sub-class of {Location} related to this Item.
        #
        # In other words, the {#semantic_type} of this Item's {Location}.
        #
        # @return [Class, nil]
        #
        def location_type
          Actions::Semantics.get_location_type(self)&.ruby_class
        end

        #
        # @!attribute [r] equipment
        #
        # Gets the related {Equipment} Item of this Item.
        #
        # Checks ancestor groups one level at a time, returning the first {Equipment} Item found.
        #
        # @return [Item, nil]
        #
        def equipment
          Actions::Semantics.get_equipment(self)&.then(&Proxy.method(:new))
        end

        #
        # @!attribute [r] equipment_type
        #
        # Returns the sub-class of {Equipment} related to this Item.
        #
        # In other words, the {#semantic_type} of this Item's {Equipment}.
        #
        # @return [Class, nil]
        #
        def equipment_type
          Actions::Semantics.get_equipment_type(self)&.ruby_class
        end

        #
        # @!attribute [r] point_type
        #
        # Returns the sub-class of {Point} this Item is tagged with.
        #
        # @return [Class, nil]
        #
        def point_type
          Actions::Semantics.get_point_type(self)&.ruby_class
        end

        #
        # @!attribute [r] property_type
        #
        # Returns the sub-class of {Property} this Item is tagged with.
        #
        # @return [Class, nil]
        #
        def property_type
          Actions::Semantics.get_property_type(self)&.ruby_class
        end

        # @!attribute [r] semantic_type
        #
        # Returns the sub-class of {Tag} this Item is tagged with.
        #
        # It will only return the first applicable Tag, preferring
        # a sub-class of {Location}, {Equipment}, or {Point} first,
        # and if none of those are found, looks for a {Property}.
        #
        # @return [Class, nil]
        #
        def semantic_type
          Actions::Semantics.get_semantic_type(self)&.ruby_class
        end

        #
        # Return the related Point Items.
        #
        # Searches this Equipment Item for Points that are tagged appropriately.
        #
        # If called on a Point Item, it will automatically search for sibling Points
        # (and remove itself if found).
        #
        # @example Get all points for a TV
        #   eGreatTV.points
        # @example Search an Equipment item for its switch
        #   eGuestFan.points(Semantics::Switch) # => [GuestFan_Dimmer]
        # @example Search a Thermostat item for its current temperature item
        #   eFamilyThermostat.points(Semantics::Status, Semantics::Temperature)
        #   # => [FamilyThermostat_AmbTemp]
        # @example Search a Thermostat item for is setpoints
        #   eFamilyThermostat.points(Semantics::Control, Semantics::Temperature)
        #   # => [FamilyThermostat_HeatingSetpoint, FamilyThermostat_CoolingSetpoint]
        # @example Given a A/V receiver's input item, search for its power item
        #   FamilyReceiver_Input.points(Semantics::Switch) # => [FamilyReceiver_Switch]
        #
        # @param [Class] point_or_property_types
        #   Pass 1 or 2 classes that are sub-classes of {Point} or {Property}.
        #   Note that when comparing against semantic tags, it does a sub-class check.
        #   So if you search for [Control], you'll get items tagged with [Switch].
        # @return [Array<Item>]
        #
        def points(*point_or_property_types)
          return members.points(*point_or_property_types) if equipment? || location?

          # automatically search the parent equipment (or location?!) for sibling points
          result = (equipment || location)&.points(*point_or_property_types) || []
          result.delete(self)
          result
        end

        # @deprecated OH3.4 - this check is only needed for OH3.4
        if org.openhab.core.semantics.SemanticTags.respond_to?(:add)

          #
          # Adds custom semantic tags.
          #
          # @return [Array<Tag>] An array of tags successfully added.
          #
          # @overload self.add(**tags)
          #   Quickly add one or more semantic tags using the default label, empty synonyms and descriptions.
          #
          #   @param [kwargs] **tags Exactly one pair of `tag` => `parent` where tag is either a Symbol or a String
          #     for the tag to be added, and parent is either a {Tag}, a symbol or a string of an existing tag.
          #   @return [Array<Tag>] An array of tags successfully added.
          #
          #   @example Add one semantic tag `Balcony` whose parent is `Semantics::Outdoor` (Location)
          #     Semantics.add(Balcony: Semantics::Outdoor)
          #
          #   @example Add multiple semantic tags
          #     Semantics.add(Balcony: Semantics::Outdoor,
          #                   SecretRoom: Semantics::Room,
          #                   Motion: Semantics::Property)
          #
          # @overload self.add(label: nil, synonyms: "", description: "", **tags)
          #   Add a custom semantic tag with extra details.
          #
          #   @example
          #     Semantics.add(SecretRoom: Semantics::Room, label: "My Secret Room",
          #       synonyms: "HidingPlace", description: "A room that requires a special trick to enter")
          #
          #   @param [String,nil] label Optional label. When nil, infer the label from the tag name,
          #     converting `CamelCase` to `Camel Case`
          #   @param [String,Array<String,Symbol>] synonyms An array of synonyms, or a string containing a
          #     comma separated list of synonyms for this tag.
          #   @param [String] description A longer description of the tag.
          #   @param [kwargs] **tags Exactly one pair of `tag` => `parent` where tag is either a Symbol or a String
          #     for the tag to be added, and parent is either a {Tag}, a symbol or a string of an existing tag.
          #   @return [Array<Tag>] An array of tags successfully added.
          #
          def self.add(label: nil, synonyms: "", description: "", **tags)
            raise "Tags must be specified" if tags.empty?
            if (tags.length > 1) && !(label.nil? && synonyms.empty? && description.empty?)
              raise "Additional options can only be specified when creating one tag"
            end

            synonyms = synonyms.map(&:to_s).map(&:strip).join(",") if synonyms.is_a?(Array)

            tags.map do |name, parent|
              parent_is_tag = parent.respond_to?(:java_class) && parent.java_class < Tag.java_class
              parent = parent_is_tag ? parent.java_class : parent.to_s
              name = name.to_s
              org.openhab.core.semantics.SemanticTags.add(name, parent, label, synonyms, description)
                                                    &.then { const_missing(name) }
            end.compact
          end
        end

        #
        # Returns all available Semantic tags
        #
        # @return [Array<Tag>] an array containing all the Semantic tags
        #
        def self.tags
          java.util.stream.Stream.of(
            org.openhab.core.semantics.model.point.Points.stream,
            org.openhab.core.semantics.model.property.Properties.stream,
            org.openhab.core.semantics.model.equipment.Equipments.stream,
            org.openhab.core.semantics.model.location.Locations.stream
          ).flat_map(&:itself).map(&:ruby_class).iterator.to_a
        end

        #
        # Finds the semantic tag using its name, label, or synonyms.
        #
        # @param [String,Symbol] id The tag name, label, or synonym to look up
        # @param [java.util.Locale] locale The locale of the given label or synonym
        #
        # @return [Tag,nil] The semantic tag class if found, or nil if not found.
        #
        def self.lookup(id, locale = nil)
          id = id.to_sym
          return const_get(id) if constants.include?(id) || const_missing(id)

          locale = java.util.Locale.default if locale.nil?
          org.openhab.core.semantics.SemanticTags.get_by_label_or_synonym(id.to_s, locale).first&.ruby_class
        end

        #
        # Automatically looks up new semantic classes and adds them as `constants`
        #
        # @return [Tag, nil]
        #
        # @!visibility private
        def self.const_missing(sym)
          logger.trace("const missing, performing Semantics Lookup for: #{sym}")
          # @deprecated OH3.4 - the Property tag had an ID of "MeasurementProperty" in OH3.4. This was corrected in OH4.
          sym = :MeasurementProperty if sym == :Property && Gem::Version.new(Core::VERSION) < Gem::Version.new("4.0.0")

          org.openhab.core.semantics.SemanticTags.get_by_id(sym.to_s)
            &.then do |tag|
              tag = tag.ruby_class
              tag.singleton_class.include(TagClassMethods)
              const_set(sym, tag)
            end
        end

        #
        # Adds tag attributes to the semantic tag class
        #
        module TagClassMethods
          # @!visibility private
          java_import org.openhab.core.semantics.SemanticTags

          #
          # Returns the tag's label
          #
          # @param [java.util.Locale] locale The locale that the label should be in, if available.
          #   When nil, the system's default locale is used.
          #
          # @return [String] The tag's label
          #
          def label(locale = nil)
            SemanticTags.get_label(java_class, locale || java.util.Locale.default)
          end

          #
          # Returns the tag's synonyms
          #
          # @param [java.util.Locale] locale The locale that the label should be in, if available.
          #   When nil, the system's default locale is used.
          #
          # @return [Array<String>] The list of synonyms in the requested locale.
          #
          def synonyms(locale = nil)
            unless SemanticTags.respond_to?(:get_synonyms) # @deprecated OH3.4
              return java_class.get_annotation(org.openhab.core.semantics.TagInfo.java_class).synonyms
                               .split(",").map(&:strip)
            end

            SemanticTags.get_synonyms(java_class, locale || java.util.Locale.default).to_a
          end

          #
          # Returns the tag's description
          #
          # @param [java.util.Locale] locale The locale that the description should be in, if available.
          #   When nil, the system's default locale is used.
          #
          # @return [String] The tag's description
          #
          def description(locale = nil)
            unless SemanticTags.respond_to?(:get_description) # @deprecated OH3.4
              return java_class.get_annotation(org.openhab.core.semantics.TagInfo.java_class).description
            end

            SemanticTags.get_description(java_class, locale || java.util.Locale.default)
          end
        end
      end
    end
  end
end

# @!parse Semantics = OpenHAB::Core::Items::Semantics

# Additions to Enumerable to allow easily filtering groups of items based on the semantic model
module Enumerable
  #
  # @!group Filtering Methods
  #

  # Returns a new array of items that are a semantics Location (optionally of the given type)
  # @return [Array<Item>]
  def locations(type = nil)
    if type && (!type.is_a?(Module) || !(type < Semantics::Location))
      raise ArgumentError, "type must be a subclass of Location"
    end

    result = select(&:location?)
    result.select! { |i| i.location_type <= type } if type

    result
  end

  # Returns a new array of items that are a semantics equipment (optionally of the given type)
  #
  # @note As {Semantics::Equipment equipments} are usually
  #   {GroupItem GroupItems}, this method therefore returns an array of
  #   {GroupItem GroupItems}. In order to get the {Semantics::Point points}
  #   that belong to the {Semantics::Equipment equipments}, use {#members}
  #   before calling {#points}. See the example with {#points}.
  #
  # @return [Array<Item>]
  #
  # @example Get all TVs in a room
  #   lGreatRoom.equipments(Semantics::Screen)
  def equipments(type = nil)
    if type && (!type.is_a?(Module) || !(type < Semantics::Equipment))
      raise ArgumentError, "type must be a subclass of Equipment"
    end

    result = select(&:equipment?)
    result.select! { |i| i.equipment_type <= type } if type

    result
  end

  # Returns a new array of items that are semantics points (optionally of a given type)
  #
  # @return [Array<Item>]
  #
  # @example Get all the power switch items for every equipment in a room
  #   lGreatRoom.equipments.members.points(Semantics::Switch)
  #
  # @see #members
  #
  def points(*point_or_property_types)
    unless (0..2).cover?(point_or_property_types.length)
      raise ArgumentError, "wrong number of arguments (given #{point_or_property_types.length}, expected 0..2)"
    end
    unless point_or_property_types.all? do |tag|
             tag.is_a?(Module) &&
             (tag < Semantics::Point ||
              tag < Semantics::Property)
           end
      raise ArgumentError, "point_or_property_types must all be a subclass of Point or Property"
    end
    if point_or_property_types.count { |tag| tag < Semantics::Point } > 1 ||
       point_or_property_types.count { |tag| tag < Semantics::Property } > 1
      raise ArgumentError, "point_or_property_types cannot both be a subclass of Point or Property"
    end

    select do |point|
      point.point? && point_or_property_types.all? do |tag|
        (tag < Semantics::Point && point.point_type <= tag) ||
          (tag < Semantics::Property && point.property_type&.<=(tag))
      end
    end
  end
end
