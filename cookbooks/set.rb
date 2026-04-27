log = MItamae.logger

args = ARGV.dup
necessary_args = [
  /\/mitamae.*/,
  /^local$/,
  /.*\/set\.rb$/
]

loop do
  p [args, necessary_args]
  top_arg = args.first
  matched_arg = necessary_args.find{ |a| p [a,top_arg]; a.match?(top_arg) }

  if !matched_arg.nil?
    necessary_args.delete matched_arg
    args.shift
  else
    if /^--?/.match?(top_arg)
      args.shift
      continue
    end
    break if necessary_args.empty?
  end
end

args.shift if args.first =~ /mitamae.*/
args.shift if args.first == 'local'
args.shift if args.first =~ /^--.*=/
args.shift if args.first =~ /set\.rb/

ARGV.shift; # mitamae
ARGV.shift; # local
ARGV.shift; # set.rb

# RUNTIME_YAML = "/etc/mitamae/data/runtime.yaml".freeze
RUNTIME_YAML = 'data/vars/mail.yml'

if ARGV.empty? || ARGV.length > 2
  $stderr.puts "Usage: mitamae cookbooks/set.rb <key> [<value>]\n"
  Kernel.exit(1)
end

key_path  = ARGV.shift
value     = ARGV.shift

data = if File.exist?(RUNTIME_YAML)
  YAML.load(File.read(RUNTIME_YAML)) || {}
else
  {}
end

keys = key_path.split(':')

if value
  # puts "Set #{key_path} = #{value} in #{RUNTIME_YAML}"
  last_key = keys.pop
  target = keys.inject(data) { |h, k| h[k] ||= {} }

  log.info "#{key_path} = #{value}"
  log.debug "(was #{target[last_key]})"
  target[last_key] = value

  File.open(RUNTIME_YAML, 'w') do |f|
    f.puts(YAML.dump(data))
  end
else
  # puts "Get #{key_path} from #{RUNTIME_YAML}"
  value = keys.inject(data) { |h, k| h[k] ||= {} }
  log.info "#{key_path} = #{value}"
end



Kernel.exit 0