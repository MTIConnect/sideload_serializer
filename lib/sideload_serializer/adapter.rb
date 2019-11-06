require 'active_model_serializers'

module SideloadSerializer
  class Adapter < ActiveModelSerializers::Adapter::Base

    def self.default_key_transform
      :camel_lower
    end

    def initialize(serializer, options = {})
      super
      @include_tree = JSONAPI::IncludeDirective.new(options[:include] || '*', allow_wildcard: true)
    end

    def serializable_hash(options={})
      options = serialization_options(options)
      serialized_hash = Hash.new { |h, k| h[k] = [] }
      add_serializer_to_document serializer, serialized_hash, Hash.new, @include_tree
      serialized_hash[:meta] = meta unless meta.blank?

      self.class.transform_key_casing!(serialized_hash, instance_options)
    end

    def as_json(options={})
      serializable_hash(options)
    end

    def add_serializer_to_document serializer_instance, document, serialized_keys, include_tree
      return unless serializer_instance && serializer_instance.object
      if collection_serializer_given? serializer_instance
        serializer_instance.each do |s|
          add_serializer_to_document s, document, serialized_keys, include_tree
        end
      else
        cache_key = serializer_instance.object.cache_key rescue serializer_instance.object.hash
        return if serialized_keys.has_key? cache_key

        add_relationship_keys serializer_instance, serializer_instance.attributes, include_tree

        document[root(serializer_instance)].push(serializer_instance.attributes)

        serialized_keys[cache_key] = true

        serializer_instance.associations(include_tree).each do |association|
          add_serializer_to_document association.lazy_association.serializer, document, serialized_keys, include_tree[association.key]
        end
      end

      document
    end

    def root serializer_instance=serializer
      serializer_instance.json_key.to_s.split('/')[0].to_s.pluralize.to_sym
    end

    def meta
      compiled_meta = {
        primary_resource_collection: CaseTransform.send(self.class.transform(instance_options), root)
      }

      unless collection_serializer_given?
        compiled_meta[:primary_resource_id] = resource_identifier_id
      end

      compiled_meta.merge(instance_options.fetch(:meta, Hash.new))
    end

    protected

    def collection_serializer_given? serializer_instance=serializer
      serializer_instance.respond_to? :each
    end

    def embed_id_key_for association
      extension = '_id'
      extension += 's' if collection_serializer_given? association.lazy_association.serializer
      association_key = association.key.to_s.singularize

      :"#{association_key}#{extension}" # this is hokey, refactor. Can we interrogate the serializer/association for this information?
    end

    def embed_collection_key_for association
      association_key = association.key

      :"#{association_key}_collection"
    end

    def resource_identifier_id serializer_instance=serializer
      if serializer_instance.respond_to?(:id)
        serializer_instance.id
      else
        serializer_instance.object.id
      end
    end

    def add_relationship_keys serializer_instance, attributes, include_tree
      serializer_instance.associations(include_tree).each do |association|
        attributes[embed_id_key_for(association)] = relationship_id_value_for association
        attributes[embed_collection_key_for(association)] = root(association.lazy_association.serializer)
      end
    end

    def relationship_id_value_for association
      return association.virtual_value if association.virtual_value
      return unless association.lazy_association.serializer && association.lazy_association.serializer.object

      if collection_serializer_given? association.lazy_association.serializer
        association.lazy_association.serializer.map do |s|
          resource_identifier_id s
        end
      else
        resource_identifier_id association.lazy_association.serializer
      end
    end
  end
end
