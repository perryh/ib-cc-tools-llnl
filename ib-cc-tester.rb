#!/usr/bin/ruby
# Script for generating optimal settings for Congestion Control in OpenSM using LNET self-test tool
# Perry Huang
# huang32@llnl.gov

=begin
Usage (run as superuser):
1. Create your lnet self-test script and use "lst stat --bw group1 group2 & sleep 30" to monitor groups
2. Example: ./ib-cc-tester -s ~/congest.sh -c /etc/opensm.conf -m /usr/sbin/opensm -o results_folder

For a test or generate a more detailed set, run with --detailed flag.

For more help, run with only --help flag.

If you only want to generate the conf files (with no testing and no root required), then run with --generate and supply an output folder with --output (--detailed optional).
=end


require 'optparse'

# argument parser included from http://florianpilz.github.com/micro-optparse/
# uses MIT license
class Parser
  attr_accessor :banner, :version
  def initialize
    @options = []
    @used_short = []
    @default_values = nil
    yield self if block_given?
  end

  def option(name, desc, settings = {})
    @options << [name, desc, settings]
  end

  def short_from(name)
    name.to_s.chars.each do |c|
      next if @used_short.include?(c) || c == "_"
      return c # returns from short_from method
    end
  end

  def process!(arguments = ARGV)
    @result = (@default_values || {}).clone # reset or new
    @optionparser ||= OptionParser.new do |p| # prepare only once
      @options.each do |o|
        @used_short << short = o[2][:short] || short_from(o[0])
        @result[o[0]] = o[2][:default] || false # set default
        klass = o[2][:default].class == Fixnum ? Integer : o[2][:default].class

        if [TrueClass, FalseClass, NilClass].include?(klass) # boolean switch
          p.on("-" << short, "--[no-]" << o[0].to_s.gsub("_", "-"), o[1]) {|x| @result[o[0]] = x}
        else # argument with parameter
          p.on("-" << short, "--" << o[0].to_s.gsub("_", "-") << " " << o[2][:default].to_s, klass, o[1]) {|x| @result[o[0]] = x}
        end
      end

      p.banner = @banner unless @banner.nil?
      p.on_tail("-h", "--help", "Show this message") {puts p ; exit}
      short = @used_short.include?("v") ? "-V" : "-v"
      p.on_tail(short, "--version", "Print version") {puts @version ; exit} unless @version.nil?
      @default_values = @result.clone # save default values to reset @result in subsequent calls
    end

    begin
      @optionparser.parse!(arguments)
    rescue OptionParser::ParseError => e
      puts e.message ; exit(1)
    end

    validate(@result) if self.respond_to?("validate")
    @result
  end
end

# begin Perry's code
def generate_cct_simula_llnl()
  retval = String.new
  num_entries = 128

  num_entries.times {|i|
    current = ((i ** 2) * 7) / (1.0 * 106 ** 2)
    current = current.to_f / 0.408
    entry = "3:" + current.to_i.to_s
    if(i == 0)
      retval = entry
    else
      retval += ","
      retval += entry
    end
  }
  return retval
end


def generate_conf(ccti_timer, threshold, marking_rate, new_file_name)
  `cp #{$config_location} #{new_file_name}`
  index_file = File.open("#{$output_location}/index_file", "a")

  new_file = File.open("#{new_file_name}", "a")
  new_file.puts(
    "congestion_control TRUE
cc_key 0x0000000000000000
cc_max_outstanding_mads 500
cc_sw_cong_setting_control_map 0x1f
cc_sw_cong_setting_victim_mask 0x000000000000000000000000000000000000000000000000001ffffffffe
cc_sw_cong_setting_credit_mask 0x0000000000000000000000000000000000000000000000000000000000000000
cc_sw_cong_setting_threshold #{threshold}
cc_sw_cong_setting_packet_size 1
cc_sw_cong_setting_credit_starvation_threshold 0x00
cc_sw_cong_setting_marking_rate #{marking_rate}
cc_ca_cong_setting_port_control 0x0001")
  num_SL_binary = 0b0
  $num_SL.times { |i|
    num_SL_binary |= 1 << i
  }
  control_map = "0x%04X" % num_SL_binary
  new_file.puts "cc_ca_cong_setting_control_map #{control_map}"
  $num_SL.times { |i|
    new_file.puts(
      "cc_ca_cong_setting_ccti_timer #{i} #{ccti_timer}
cc_ca_cong_setting_ccti_increase #{i} 1
cc_ca_cong_setting_trigger_threshold #{i} 1
cc_ca_cong_setting_ccti_min #{i} 0")
  }
  new_file.puts "cc_cct #{generate_cct_simula_llnl()}"
  new_file.close

  index_file.puts new_file_name
  index_file.puts(
    "cc_ca_cong_setting_ccti_timer = #{ccti_timer}
cc_sw_cong_setting_threshold #{threshold}
cc_sw_cong_setting_marking_rate #{marking_rate}")
  index_file.puts "============"
  index_file.close
  return
end

def test_lnet(ccti_timer, threshold, marking_rate)

  group = String.new
  count = 0
  smart_counter = 0

  `mkdir #{$output_location}`
  `mkdir #{$output_location}/conf/`
  `touch #{$output_location}/results.out`
  total = ccti_timer.count + threshold.count + marking_rate.count

  ccti_timer.each do |ccti_timer_i|
    threshold.each do |threshold_i|
      marking_rate.each do |marking_rate_i|
        results = Hash.new([0.0, 0.0])
        file = File.new("#{$output_location}/results.out", "a")
        generate_conf(ccti_timer_i, threshold_i, marking_rate_i, "#{$output_location}/conf/conf#{count}")
        opensm_process_id = fork do
          exec "#{$opensm_location}", "--conf", "#{$output_location}/conf/conf#{count}"
        end
        sleep $timer
        retval = `sh #{$script_location}`
        retval = retval.split("\n")
        first_flag = true
        first_group = String.new
        first_group_counter = 0
        retval.each do |line|
          line_split = line.split
          if(line.include? "[LNet Bandwidth of ")
            smart_counter = 1
            group = line_split[3]
            group = group.sub("]", "")
            if(first_flag == true)
              first_group = group
              first_flag == false
              first_group_counter = 1
            elsif(first_group == group)
              first_group_counter = first_group_counter + 1
            end
            results[group] = [0.0, 0.0]
          elsif(smart_counter == 0)
            next
          elsif(smart_counter == 1)
            smart_counter = smart_counter + 1
            avg_read = line_split[2]
            results[group][0] += avg_read.to_f
          elsif(smart_counter == 2)
            smart_counter = 0
            avg_write = line_split[2]
            results[group][1] += avg_write.to_f
          end
        end

        if(first_group_counter == 0)
          fail("Error: No groups found. Use \"lst stat\" to monitor groups!")
        end
        results.each_value do |val|
          val[0] = val[0] * first_group_counter
          val[1] = val[1] * first_group_counter
        end

        file.puts "file: #{$output}/conf/conf#{count}"
        results.each {|key, val|
          file.puts "group: #{key}"
          file.puts "avg read: #{val[0]}"
          file.puts "avg write: #{val[1]}"
        }
        file.puts "============"
        Process.kill("SIGKILL", opensm_process_id)
        count = count + 1
        puts "#{count} out of #{total} (#{(count.to_f / total.to_f) * 100}%) completed."
        file.close
      end
    end
  end
  return
end

def no_test(ccti_timer, threshold, marking_rate)
  `mkdir #{$output_location}`
  `mkdir #{$output_location}/conf/`
  count = 0
  ccti_timer.each do |ccti_timer_i|
    threshold.each do |threshold_i|
      marking_rate.each do |marking_rate_i|
        generate_conf(ccti_timer_i, threshold_i, marking_rate_i, "#{$output_location}/conf/conf#{count}")
        count = count + 1
      end
    end
  end
end

options = Parser.new do |p|
  p.banner = "Tool for analyzing lnet self-test performance with different OpenSM congestion control settings\nSupport: Perry Huang (huang32@llnl.gov)"
  p.version = "ib-cc-tester 1.0 by Perry Huang (huang32@llnl.gov)"
  p.option :script, "LNET self-test script location", :default => "lnet_test.sh", :short => "s"
  p.option :config, "local OpenSM conf", :default => "/etc/opensm.conf", :short => "c"
  p.option :opensm, "OpenSM location", :default => "/usr/sbin/opensm", :short => "m"
  p.option :output, "results output folder location", :default => "lnet_cc_folder", :short => "o"
  p.option :detailed, "use a detailed test (takes very long)", :default => false
  p.option :service_levels, "number of Service Levels (SLs)", :default => "8", :short => "n"
  p.option :generate_only, "only generate conf files (do not test)", :default => false, :short => "g"
  p.option :timer, "seconds after calling OpenSM before launching test", :default => "15", :short => "t"
end.process!

if(!File.exists?(options[:config]))
  fail("Local opensm.conf cannot be found!")
elsif(!File.exists?(options[:opensm]) and options[:generate_only] == false)
  fail("OpenSM binary cannot be found!")
elsif(File.exists?(options[:output]))
  fail("Output folder already exists. Please choose another.")
end

$script_location = options[:script]
$config_location = options[:config]
$opensm_location = options[:opensm]
$output_location = options[:output]
$num_SL = options[:service_levels].to_i
$timer = options[:timer].to_i

if(options[:detailed] == false)
  ccti_timer = ["150", "600", "1200", "1500", "1700", "1900", "2100", "2300", "4000", "6000"]
  threshold = ["0xf", "0x9"]
  marking_rate = ["0x000f"]
else
  ccti_timer = []
  i = 100
  while(i < 3000)
    ccti_timer << i.to_s
    i += 50
  end
  threshold = ["0x5", "0x9", "0xc", "0xf"]
  marking_rate = ["0x000f"]
end

if(options[:generate_only])
  no_test(ccti_timer, threshold, marking_rate)
else
  test_lnet(ccti_timer, threshold, marking_rate)
end

exit
