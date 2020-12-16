# typed: strict
# frozen_string_literal: true

require "erb"

module Tapioca
  module Testing
    module OutputHelpers
      extend T::Sig

      class ErbBinding
        extend T::Sig

        ERB_SUPPORTS_KVARGS = T.let(
          ::ERB.instance_method(:initialize).parameters.assoc(:key),
          T.nilable([Symbol, Symbol])
        )

        sig { params(selector: String).returns(T::Boolean) }
        def ruby_version(selector)
          Gem::Requirement.new(selector).satisfied_by?(Gem::Version.new(RUBY_VERSION))
        end
      end
      private_constant :ErbBinding

      sig { params(src: String).returns(String) }
      def template(src)
        erb = if ErbBinding::ERB_SUPPORTS_KVARGS
          ::ERB.new(src, trim_mode: ">")
        else
          ::ERB.new(src, nil, ">")
        end

        erb.result(ErbBinding.new.instance_exec { binding })
      end

      sig { params(str: String, indent: Integer).returns(String) }
      def indented(str, indent)
        str.lines.map! do |line|
          next line if line.chomp.empty?
          " " * indent + line
        end.join
      end
    end
  end
end