module Virtus
  class Attribute

    # Abstract superclass for collection Attributes.
    #
    # Handles coercing members to the designated member type.
    #
    # @abstract
    class Collection < Attribute
      default Proc.new { |_, attribute| attribute.type.primitive.new }

      attr_reader :member_type

      # FIXME: temporary hack, remove when Axiom::Type works with EV as member_type
      Type = Struct.new(:primitive, :member_type) do
        def self.infer(type, primitive)
          return type if axiom_type?(type)

          klass  = Axiom::Types.infer(type)
          member = infer_member_type(type) || Object

          if EmbeddedValue.handles?(member) || pending?(member)
            Type.new(primitive, member)
          else
            klass.new {
              primitive primitive
              member_type Axiom::Types.infer(member)
            }
          end
        end

        def self.pending?(primitive)
          primitive.is_a?(String) || primitive.is_a?(Symbol)
        end

        def self.axiom_type?(type)
          type.is_a?(Class) && type < Axiom::Types::Type
        end

        def self.infer_member_type(type)
          return unless type.respond_to?(:count)

          if type.count > 1
            raise NotImplementedError, "build SumType from list of types (#{type})"
          else
            type.first
          end
        end

        def coercion_method
          :to_array
        end
      end

      # @api private
      def self.build_type(definition)
        Type.infer(definition.type, definition.primitive)
      end

      # @api private
      def self.merge_options!(type, options)
        unless options.key?(:member_type)
          options[:member_type] = Attribute.build(type.member_type)
        end
      end

      # @api public
      def coerce(*)
        super.each_with_object(primitive.new) do |entry, collection|
          collection << member_type.coerce(entry)
        end
      end

      # @api private
      def finalize
        return self if finalized?
        @member_type = @options[:member_type].finalize
        super
      end

      # @api private
      def finalized?
        super && member_type.finalized?
      end

    end # class Collection

  end # class Attribute
end # module Virtus
