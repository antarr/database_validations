module DatabaseValidations
  module Helpers
    module_function

    def cache_valid_method!(klass)
      return if klass.method_defined?(:valid_without_database_validations?)

      klass.alias_method(:valid_without_database_validations?, :valid?)
    end

    def handle_error!(instance, error)
      case error
      when ActiveRecord::RecordNotUnique
        handle_unique_error!(instance, error)
      when ActiveRecord::InvalidForeignKey
        handle_foreign_key_error!(instance, error)
      else false
      end
    end

    def handle_unique_error!(instance, error)
      adapter = Adapters.factory(instance.class)

      keys = [
        generate_key_for_uniqueness_index(adapter.unique_index_name(error.message)),
        generate_key_for_uniqueness(adapter.unique_error_columns(error.message))
      ]

      each_options_storage(instance.class) do |storage|
        keys.each { |key| return storage[key].handle_unique_error(instance) if storage[key] }
      end

      false
    end

    def handle_foreign_key_error!(instance, error)
      adapter = Adapters.factory(instance.class)
      column_key = generate_key_for_belongs_to(adapter.foreign_key_error_column(error.message))

      each_options_storage(instance.class) do |storage|
        return storage[column_key].handle_foreign_key_error(instance) if storage[column_key]
      end

      false
    end

    def each_options_storage(klass)
      while klass.respond_to?(:validates_db_uniqueness_of)
        storage = storage_of(klass)
        yield(storage) if storage
        klass = klass.superclass
      end
    end

    def storage_of(klass)
      klass.instance_variable_get(:'@database_validations_storage')
    end

    def unify_columns(*args)
      args.flatten.compact.map(&:to_s).sort
    end

    def generate_key_for_uniqueness_index(index_name)
      generate_key(:uniqueness_index, index_name)
    end

    def generate_key_for_uniqueness(*columns)
      generate_key(:uniqueness, columns)
    end

    def generate_key_for_belongs_to(column)
      generate_key(:belongs_to, column)
    end

    def generate_key(type, *args)
      [type, *unify_columns(args)].join('__')
    end
  end
end
