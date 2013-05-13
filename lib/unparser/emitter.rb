module Unparser

  # Emitter base class
  class Emitter
    include AbstractType, Equalizer.new(:node, :buffer)

    # Registry of node emitters
    REGISTRY = {}

    # Register emitter for type
    #
    # @param [Symbol] type
    #
    # @return [undefined]
    #
    # @api private
    #
    def self.handle(*types)
      types.each do |type|
        REGISTRY[type] = self
      end
    end
    private_class_method :handle

    # Visit node
    #
    # @param [Parser::AST::Node] node
    # @param [Buffer] buffer
    #
    # @return [Emitter]
    #
    # @api private
    #
    def self.visit(node, buffer)
      type = node.type
      emitter = REGISTRY.fetch(type) do 
        raise ArgumentError, "No emitter for node: #{type.inspect}"
      end
      emitter.emit(node, buffer)
      self
    end

    abstract_singleton_method :emit

    module InstanceEmitter
      module ClassMethods

        # Emit node into buffer
        #
        # @param [Parser::AST::Node] node
        # @param [Buffer] buffer
        #
        # @return [self]
        #
        # @api private
        #
        def emit(node, buffer)
          new(node, buffer)
          self
        end

      end


      module InstanceMethods

        # Initialize object
        #
        # @param [Parser::AST::Node] node
        # @param [Buffer] buffer
        #
        # @return [undefined]
        #
        # @api private
        #
        def initialize(node, buffer)
          @node, @buffer = node, buffer
          dispatch
        end

        # Return node
        #
        # @return [Parser::AST::Node] node
        #
        # @api private
        #
        attr_reader :node

        # Return buffer
        #
        # @return [Buffer] buffer
        #
        # @api private
        #
        attr_reader :buffer

        def emit_source_map
          SourceMap.emit(node, buffer)
        end

      private

        # Emit contents of block within parentheses
        #
        # @return [undefined]
        #
        # @api private
        #
        def parentheses(open='(', close=')')
          write(open)
          yield
          write(close)
        end

        # Dispatch helper
        #
        # @param [Parser::AST::Node] node
        #
        # @return [undefined]
        #
        # @api private
        #
        def visit(node)
          self.class.visit(node, buffer)
        end

        # Emit delimited body
        #
        # @param [Enumerable<Parser::AST::Node>] nodes
        # @param [String] delimiter
        #
        # @return [undefined]
        #
        # @api private
        #
        def delimited(nodes, delimiter)
          max = nodes.length - 1
          nodes.each_with_index do |node, index|
            visit(node)
            write(delimiter) if index < max
          end
        end

        # Return children of node
        #
        # @return [Array<Parser::AST::Node>]
        #
        # @api private
        #
        def children
          node.children
        end

        # Write string into buffer
        #
        # @param [String] string
        #
        # @return [undefined]
        #
        # @api private
        #
        def write(string)
          buffer.append(string)
        end

      end

      # Hook called when module is included
      #
      # @param [Module,Class] descendant
      #
      # @return [undefined]
      #
      # @api private
      #
      def self.included(descendant)
        descendant.instance_eval do
          include InstanceMethods
          extend ClassMethods
        end
      end
    end

  private

    class Access < self

      handle :ivar, :lvar, :cvar, :gvar

      # Perform dispatch
      #
      # @return [undefined]
      #
      # @api private
      #
      def self.emit(node, buffer)
        buffer.append(node.children.first.to_s)
      end

    end

    class CBase < self
      BASE = '::'.freeze

      handle :cbase

      # Perform dispatch
      #
      # @param [Parser::AST::Node] node
      # @param [Buffer] buffer
      #
      # @return [self]
      #
      # @api private
      #
      def self.emit(node, buffer)
        buffer.append(BASE)
      end
    end

    # Emitter that fully relies on parser source maps
    class SourceMap < self

      # Perform dispatch
      #
      # @return [self]
      #
      # @api private
      #
      def self.emit(node, buffer)
        buffer.append(node.source_map.expression.to_source)
        self
      end

    end # SourceMap
  end # Emitter
end # Unparser
