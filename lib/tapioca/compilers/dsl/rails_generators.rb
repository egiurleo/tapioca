# typed: strict
# frozen_string_literal: true

begin
  require "rails/generators"
  require "rails/generators/app_base"
rescue LoadError
  return
end

module Tapioca
  module Compilers
    module Dsl
      # `Tapioca::Compilers::Dsl::RailsGenerators` generates RBI files for Rails generators
      #
      # For example, with the following generator:
      #
      # ~~~rb
      # # lib/generators/sample_generator.rb
      # class ServiceGenerator < Rails::Generators::NamedBase
      #   argument :result_type, type: :string
      #
      #   class_option :skip_comments, type: :boolean, default: false
      # end
      # ~~~
      #
      # this compiler will produce the RBI file `service_generator.rbi` with the following content:
      #
      # ~~~rbi
      # # service_generator.rbi
      # # typed: strong
      #
      # class ServiceGenerator
      #   sig { returns(::String)}
      #   def result_type; end
      #
      #   sig { returns(T::Boolean)}
      #   def skip_comments; end
      # end
      # ~~~
      class RailsGenerators < Base
        extend T::Sig

        BUILT_IN_MATCHER = T.let(
          /::(ActionMailbox|ActionText|ActiveRecord|Rails)::Generators/,
          Regexp
        )

        sig do
          override
            .params(
              root: RBI::Tree,
              constant: T.class_of(::Rails::Generators::Base)
            )
            .void
        end
        def decorate(root, constant)
          base_class = base_class_for(constant)
          arguments = constant.arguments - base_class.arguments
          class_options = constant.class_options.reject do |name, option|
            base_class.class_options[name] == option
          end

          return if arguments.empty? && class_options.empty?

          root.create_path(constant) do |klass|
            arguments.each { |argument| generate_methods_for_argument(klass, argument) }
            class_options.each { |_name, option| generate_methods_for_argument(klass, option) }
          end
        end

        sig { override.returns(T::Enumerable[Module]) }
        def gather_constants
          all_modules.select do |const|
            name = qualified_name_of(const)

            name &&
              !name.match?(BUILT_IN_MATCHER) &&
              const < ::Rails::Generators::Base
          end
        end

        private

        sig do
          params(klass: RBI::Tree, argument: T.any(Thor::Argument, Thor::Option)).void
        end
        def generate_methods_for_argument(klass, argument)
          type = type_for(argument)

          klass.create_method(
            argument.name,
            parameters: [],
            return_type: type
          )
        end

        sig do
          params(constant: T.class_of(::Rails::Generators::Base))
            .returns(T.class_of(::Rails::Generators::Base))
        end
        def base_class_for(constant)
          ancestor = inherited_ancestors_of(constant).find do |klass|
            qualified_name_of(klass)&.match?(BUILT_IN_MATCHER)
          end

          T.cast(ancestor, T.class_of(::Rails::Generators::Base))
        end

        sig { params(arg: T.any(Thor::Argument, Thor::Option)).returns(String) }
        def type_for(arg)
          type =
            case arg.type
            when :array then "T::Array[::String]"
            when :boolean then "T::Boolean"
            when :hash then "T::Hash[::String, ::String]"
            when :numeric then "::Numeric"
            when :string then "::String"
            else "T.untyped"
            end

          if arg.required || arg.default
            type
          else
            "T.nilable(#{type})"
          end
        end
      end
    end
  end
end
