require 'shellwords'
require 'mediakit/utils/popen_helper'

module Mediakit
  module Drivers
    class DriverError < StandardError; end
    class FailError < DriverError; end
    class ConfigurationError < DriverError; end

    class Base
      attr_reader(:bin)
      def initialize(bin)
        @bin = bin
      end

      def run(*args)
        raise(NotImplementedError)
      end

      def command(*args)
        raise(NotImplementedError)
      end
    end

    class PopenDriver < Base
      # execute command and return result
      #
      # @overload run(args)
      #   @param args [String] arguments for command
      # @overload run(*args)
      #   @param args [Array] arguments for command
      # @return result [Bool] runners result
      def run(*args)
        begin
          escaped_args = Mediakit::Utils::PopenHelper.escape(*args)
          stdout, stderr, exit_status = Mediakit::Utils::PopenHelper.run(bin, escaped_args)
          raise(FailError, stderr) unless exit_status
          stdout
        rescue Mediakit::Utils::PopenHelper::CommandNotFoundError => e
          raise(ConfigurationError, "cant' find bin in #{bin}.")
        end
      end

      # return command to execute
      #
      # @overload run(args)
      #   @param args [String] arguments for command
      # @overload run(*args)
      #   @param args [Array] arguments for command
      # @return result [String] runners to execute
      def command(*args)
        escaped_args = Mediakit::Utils::PopenHelper.escape(*args)
        "#{bin} #{escaped_args}"
      end
    end

    class CocaineDriver < Base
      # execute command and return result
      #
      # @overload run(args)
      #   @param args [String] arguments for command
      # @overload run(*args)
      #   @param args [Array] arguments for command
      # @return result [Bool] runners result
      def run(args = '')
        begin
          # Force escape args string on here,
          # because this design can't use Cocaine::CommandLine's safety solution.
          escaped_args = Mediakit::Utils::PopenHelper.escape(args.dup)
          command_line = Cocaine::CommandLine.new(bin, escaped_args, swallow_stderr: true)
          command_line.run
        rescue Cocaine::ExitStatusError => e
          raise(FailError, e.message)
        end
      end

      # return command to execute
      #
      # @overload run(args)
      #   @param args [String] arguments for command
      # @overload run(*args)
      #   @param args [Array] arguments for command
      # @return result [String] runners to execute
      def command(args = '')
        Cocaine::CommandLine.new(bin, args).command
      end
    end

    class FakeDriver < Base
      def run(args = '')
        true
      end

      def command(args = '')
        bin + args
      end
    end

    class AbstractFactory
      class << self
        attr_accessor(:bin_path)

        def configure(&block)
          yield(self)
        end

        def name
          self.to_s.downcase.split('::').last
        end

        def bin
          bin_path || name
        end

        def new(type = :popen)
          case type.to_sym
          when :popen
            PopenDriver.new(bin)
          when :cocaine
            CocaineDriver.new(bin)
          when :fake
            FakeDriver.new(bin)
          else
            raise(ArgumentError)
          end
        end
      end
    end

    # factory class for ffmpeg driver
    class FFmpeg < AbstractFactory
    end

    # factory class for ffprobe driver
    class FFprobe < AbstractFactory
    end

    # factory class for sox driver
    class Sox < AbstractFactory
    end
  end
end
