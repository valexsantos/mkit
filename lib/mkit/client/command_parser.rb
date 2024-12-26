# frozen_string_literal: true
#
require 'yaml'
require 'json'
require 'erb'

class InvalidParametersException < Exception
  attr_reader :command

  def initialize(cause, command = nil)
    super(cause)
    @command = command
  end
end

class CommandParser
  def initialize
    @dict = YAML.safe_load(File.read("#{File.expand_path('..', __dir__)}/client/commands.yaml"), symbolize_names: true)
  end

  def dict
    @dict
  end

  def parse(args)
    cmd = args[0]
    c = nil
    # short circuit for help
    if cmd == 'help' || args.empty?
      if args.size > 1
        c = find_command(args[1])
        raise InvalidParametersException, "'#{args[1]}' is not a valid help topic." if c.nil?
      end
      return help(cmd: c)
    else
      c = find_command(cmd)
    end
    raise InvalidParametersException, 'Command not found' if c.nil?

    command = c
    argv = args.dup
    argv.delete(cmd)

    request_data = {}
    request = command[:request]
    unless argv.empty?
      # options
      unless c[:options].nil?
        command = c[:options].select { |o| o[:cmd] == argv[0] }.first
        raise InvalidParametersException.new('Invalid parameters found.', c) if command.nil? || command.empty?

        argv.delete_at(0)
        request = command[:request]
      end
      fill_cmd_args(command[:args], argv, request, request_data)
    end
    raise InvalidParametersException.new('Invalid command or parameters.', c) if request.nil?

    fill_request_defaults(request, request_data)

    validate_command(command, request_data)
    # 
    {
      cmd: c[:cmd],
      request: request,
      data:  request_data
    }
  end

  def fill_request_defaults(request, request_data)
    if !request.nil? && !request[:defaults].nil?
      request[:defaults].each do |key, value|
        request[:params] ||= []
        unless request[:params].include?(key.to_sym)
          request[:params] << key.to_sym
          request_data[key.to_sym] = value
        end
      end
    end
  end

  # args = command[:args]
  # argv = ARGV.dup - cmd
  # request = command[:request]
  # request_data = {}
  def fill_cmd_args(args, argv, request, request_data)
    return if args.nil?
    args.each do |arg|
      arg[:type] = 'value' unless arg[:type]
    end
    split = split_argv(argv)
    argv = split[0]
    varargs = split[1]
    varargs = nil if varargs.empty?

    # find vararg and fill it
    vararg = args.select { |arg| arg[:type].to_sym == :varargs }.first
    if vararg
      request_data[vararg[:name].to_sym] = varargs
      request[:params] ||= []
      request[:params] << vararg[:name].to_sym unless request[:params].include?(vararg[:name].to_sym)
      request_data[vararg[:name].to_sym] = varargs
    end

    # flag and options
    fill_flag_and_options_args(args, argv, request, request_data)
    idx = 0
    args.each do |arg|
      if arg[:type].to_sym == :value
        request_data[arg[:name].to_sym] = argv[idx]
        fill_params_and_uri(arg, request)
      end

      idx += 1
    end
  end

  def split_argv(argv)
    separator_index = argv.index('--')
    if separator_index
      left_side = argv[0...separator_index]
      right_side = argv[(separator_index + 1)..-1]
    else
      left_side = argv
      right_side = []
    end
    [left_side, right_side]
  end

  def fill_flag_and_options_args(args, argv, request, request_data)
    # flags
    # checking flags first, avoids -n -f, with -f being the value of -n
    args.select { |arg| arg[:type].to_sym == :flag }.each do |arg|
      idx = find_option_or_flag_index(arg, argv)
      if idx
        fill_params_and_uri(arg, request)
        argv.delete_at(idx)
        request_data[arg[:name].to_sym] = arg[:param]
      end
    end
    # options
    args.select { |arg| arg[:type].to_sym == :option }.each do |arg|
      idx = find_option_or_flag_index(arg, argv)
      if idx
        fill_params_and_uri(arg, request)
        argv.delete_at(idx)
        request_data[arg[:name].to_sym] = argv[idx]
      end
    end
  end

  def find_option_or_flag_index(arg, argv)
    idx = nil
    arg[:switch].each { | switch |
      idx ||= argv.index(switch)
    }
    idx
  end

  def fill_params_and_uri(arg, request)
    request[:uri] = request[:uri] + arg[:uri] unless arg[:uri].nil?
    unless arg[:param].nil?
      request[:params] ||= []
      request[:params] << arg[:name].to_sym unless request[:params].include?(arg[:name].to_sym)
    end
  end

  def validate_command(command, request_data)
    return if command[:args].nil?

    command[:args].select { |arg| arg[:mandatory] == true }.each do |arg|
      if request_data[arg[:name].to_sym].nil?
        raise InvalidParametersException.new("Missing mandatory parameter: #{arg[:name]}", command)
      end
    end
    request_data.select{|key, value| value.nil? }.each do |key, value|
      raise InvalidParametersException.new("Missing parameter value for #{key}", command)
    end
  end

  def find_command(cmd)
    dict.select { |k| k[:cmd] == cmd }.first
  end

  def doIt(args)
    result = parse_args(args)
    puts result
  rescue InvalidParametersException => e
    help(cause: e)
  end

  def format_arg_help_msg(arg)
    _format(arg[:help][0], arg[:help][1])
  end

  def format_cmd_help_msg(command)
    _format(command[:cmd], command[:help])
  end

  def _format(arg1, srg2)
    format("%-12s %s\n", arg1, srg2)
  end

  def help(cause: nil, cmd: nil)
    msg = ''
    if cause.nil?
      my_cmd = cmd
    else
      msg += "MKIt: #{cause.message}\n"
      my_cmd = cause.command
    end
    if my_cmd.nil?
      msg += "\nUsage: mkit <command> [options]\n\n"
      msg += "Micro k8s on Ruby - a simple tool to mimic a (very) minimalistic k8 cluster\n\n"
      msg += "Commands:\n\n"
      dict.each do |c|
        msg += format_cmd_help_msg(c)
      end
      msg += "\n"
      msg += "Run ' mkit help <command>' for specific command information.\n\n"
    else
      # todo mkit help profile set
      msg += format("\nUsage: mkit %s %s\n\n", my_cmd[:cmd], my_cmd[:usage].nil? ? '' : my_cmd[:usage].join(' '))
      msg += format("%s\n", my_cmd[:help])
      if !my_cmd[:options].nil? || !my_cmd[:args].nil?
        msg += "\nOptions:\n"
        # command
        unless my_cmd[:options].nil?
          my_cmd[:options].each  do |c|
            msg += format_cmd_help_msg(c)
          end
        end
        # args
        unless my_cmd[:args].nil?
          # values only first
          cmd_args = my_cmd[:args].select{ |arg| (arg[:type].nil? || arg[:type].to_sym == :value) && !arg[:help].nil?}
          cmd_args.each do |arg|
            msg += format_arg_help_msg(arg)
          end
          cmd_args = my_cmd[:args].select{ |arg| !arg[:type].nil? && (arg[:type].to_sym == :option || arg[:type].to_sym == :flag)}
          cmd_args.each  do |arg|
            msg += format_arg_help_msg(arg)
          end
        end
      end
      msg += "\n"
    end
    puts msg
    exit 1
  end

end

