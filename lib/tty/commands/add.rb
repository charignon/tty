# encoding: utf-8
# frozen_string_literal: true

require 'ostruct'

require_relative '../cmd'
require_relative '../templater'

module TTY
  module Commands
    class Add < TTY::Cmd
      include PathHelpers

      attr_reader :app_name

      attr_reader :cmd_name

      attr_reader :subcmd_name

      attr_reader :options

      def initialize(cmd_names, options)
        @cmd_name = cmd_names[0]
        @subcmd_name = cmd_names[1]
        @app_path = relative_path_from(root_path, root_path)
        @app_name = name_from_path(root_path)
        @options  = options

        @templater = Templater.new('add', @app_path)
      end

      def template_options
        opts = OpenStruct.new
        opts[:app_name_constantinized] = app_name_constantinized
        opts[:cmd_name_constantinized] = cmd_name_constantinized
        opts[:app_name_underscored] = app_name_underscored
        opts[:cmd_name_underscored] = cmd_name_underscored
        opts[:app_constantinized_parts] = app_name_constantinized.split('::')
        opts[:cmd_constantinized_parts] = cmd_name_constantinized.split('::')
        opts[:app_indent] = app_indent
        opts[:cmd_indent] = cmd_indent
        opts[:cmd_file_path] = cmd_file_path
        opts
      end

      def color_option
        options['no-color'] ? { color: false } : {}
      end

      def execute
        validate_cmd_name(cmd_name)
        cli_file = "lib/#{app_name}/cli.rb"
        cli_content = ::File.read(cli_file)
        cmd_file = "lib/#{app_name}/commands/#{cmd_name_path}.rb"

        if subcmd_name.nil?
          @templater.add_mapping('command.rb.tt', cmd_file)
          @templater.generate(template_options, color_option)

          if !cmd_exists?(cli_content)
            match = cmd_matches.find { |m| cli_content =~ m }
            generator.inject_into_file(
              cli_file, "\n#{cmd_template}",
              {after: match}.merge(color_option))
          end
        else
          @templater.add_mapping('sub_command.rb.tt', cmd_file)
          @templater.generate(template_options, color_option)

          if !subcmd_registered?(cli_content)
            match = register_subcmd_matches.find { |m| cli_content =~ m }
            generator.inject_into_file(
              cli_file, "\n#{register_subcmd_template}",
              {after: match}.merge(color_option))
          end

          content = ::File.read(cmd_file)
          if !subcmd_exists?(content)
            match = subcmd_matches.find {|m| content =~ m }
            generator.inject_into_file(
              cmd_file, "\n#{subcmd_template}",
              {after: match}.merge(color_option))
          end
        end
      end

      def subcmd_registered?(content)
        content =~%r{\s*require_relative 'commands/#{cmd_name_path}'}
      end

      def subcmd_exists?(content)
        content =~ %r{\s*def #{subcmd_name_underscored}.*}
      end

      def cmd_exists?(content)
        content =~ %r{\s*def #{cmd_name_underscored}.*}
      end

      # Matches for inlining command defition in template
      #
      # @api private
      def cmd_matches
        [
          %r{def version.*?:version\n}m,
          %r{def version.*?#{app_indent}  end\n}m,
          %r{class CLI < Thor\n}
        ]
      end

      def subcmd_matches
        [
          %r{namespace .*?\n},
          %r{class .*? < Thor\n}
        ]
      end

      def register_subcmd_matches
        [
          %r{require_relative .*?\nregister .*?\n}m
        ].concat(cmd_matches)
      end

      private

      def cmd_template
<<-EOS
#{app_indent}  desc '#{cmd_name_underscored}', 'Command description...'
#{app_indent}  def #{cmd_name_underscored}(*)
#{app_indent}    if options[:help]
#{app_indent}      invoke :help, ['#{cmd_name_underscored}']
#{app_indent}    else
#{app_indent}      require_relative 'commands/#{cmd_name_path}'
#{app_indent}      #{cmd_object}.new(options).execute
#{app_indent}    end
#{app_indent}  end
EOS
      end

      def register_subcmd_template
<<-EOS
#{app_indent}  require_relative 'commands/#{cmd_name_path}'
#{app_indent}  register #{cmd_object}, '#{cmd_name_underscored}', '#{cmd_name_underscored} [SUBCOMMAND]', 'Command description...'
EOS
      end

      def subcmd_template
<<-EOS
#{app_indent}#{cmd_indent}  desc '#{subcmd_name_underscored}', 'Command description...'
#{app_indent}#{cmd_indent}  def #{subcmd_name_underscored}(*)
#{app_indent}#{cmd_indent}    if options[:help]
#{app_indent}#{cmd_indent}      invoke :help, ['#{subcmd_name_underscored}']
#{app_indent}#{cmd_indent}    else
#{app_indent}#{cmd_indent}      require_relative '#{cmd_name_path}/#{subcmd_name_path}'
#{app_indent}#{cmd_indent}      #{subcmd_object}.new(options).execute
#{app_indent}#{cmd_indent}    end
#{app_indent}#{cmd_indent}  end
EOS
      end

      def app_indent
        '  ' * app_name_constantinized.split('::').size
      end

      def cmd_indent
        '  ' * cmd_name_constantinized.split('::').size
      end

      def cmd_object
        "#{app_name_constantinized}::Commands::#{cmd_name_constantinized}"
      end

      def subcmd_object
        cmd_object + "::#{subcmd_name_constantinized}"
      end

      def validate_cmd_name(cmd_name)
        # TODO: check if command has correct name
      end

      def app_name_constantinized
        constantinize(app_name)
      end

      def app_name_underscored
        snake_case(app_name)
      end

      def cmd_name_constantinized
        constantinize(cmd_name)
      end

      def cmd_name_underscored
        snake_case(cmd_name)
      end

      def cmd_name_path
        cmd_name_underscored.tr('-', '/')
      end

      def cmd_file_path
        '../' * cmd_name_constantinized.split('::').size + 'cmd'
      end

      def subcmd_name_underscored
        snake_case(subcmd_name)
      end

      def subcmd_name_constantinized
        constantinize(subcmd_name)
      end

      def subcmd_name_path
        subcmd_name_underscored.tr('-', '/')
      end

      def spec_root
        Pathname.new('spec')
      end
    end # Add
  end # Commands
end # TTY
