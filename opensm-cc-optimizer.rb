#!/usr/bin/ruby
# Script for generating optimal settings for Congestion Control in OpenSM using mpiGraph
# Perry Huang
# huang32@llnl.gov

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

def test_threshold(min, max)
	if(min == max)
		puts "Found optimal threshold value for switch!"
		return max
	end

	puts "Currently testing #{min} and #{max} for switch threshold."
	mid = (min + max) / 2

	min_score = use_mpiGraph(("0x%x" % min).to_s, "300")
	max_score = use_mpiGraph(("0x%x" % max).to_s, "300")

	if(min_score > max_score)
		return test_threshold(min.to_i, mid.to_i)
	else
		return test_threshold(mid.to_i, max.to_i)
	end
end

def test_ccti_timer(min, max)
	if(min == max)
		puts "Found optimal CCTI timer value!"
		return max
	end

	puts "Currently testing #{min} and #{max} for CCTI timer."
	mid = (min + max) / 2

	min_score = use_mpiGraph("0xb", min.to_s)
	max_score = use_mpiGraph("0xb", max.to_s)

	if(min_score > max_score)
		return test_ccti_timer(min.to_i, mid.to_i)
	else
		return test_ccti_timer(mid.to_i, max.to_i)
	end
end

def use_mpiGraph(threshold, ccti_timer)
	file_name = "/tmp/opensm-cc-optimizer-conf.tmp"
	generate_optimized_conf(threshold, ccti_timer, file_name)
	opensm_process_id = fork do
		exec "#{$opensm_location}", "--conf", "#{file_name}"
	end	
	sleep 5
	retval = `srun -n #{$num_nodes} -N #{$num_nodes} -p#{$partition} #{$mpiGraph_location} | grep "Send avg"`
	sleep 5
	retval = retval.split
	Process.kill("SIGKILL", opensm_process_id)
	puts "MPIGRAPH RESULT: " + retval[2]
	return retval[2].to_i
end

def generate_optimized_conf(threshold, ccti_timer, new_file_name)
	`rm #{new_file_name}`
	if(File.exists?(new_file_name))
		fail("Something is wrong.")
	end
	`cp #{$config_location} #{new_file_name}`
	new_file = File.open("#{new_file_name}", "a")
	new_file.puts(
"congestion_control TRUE
cc_key 0x0000000000000000
cc_max_outstanding_mads 500
cc_sw_cong_setting_control_map 0x1f
cc_sw_cong_setting_victim_mask 0x000000000000000000000000000000000000000000000000001ffffffffe
cc_sw_cong_setting_credit_mask 0x0000000000000000000000000000000000000000000000000000000000000000
cc_sw_cong_setting_threshold 0x#{threshold.to_i.to_s(16)}
cc_sw_cong_setting_packet_size 1
cc_sw_cong_setting_credit_starvation_threshold 0x00
cc_sw_cong_setting_marking_rate 0x000f
cc_ca_cong_setting_port_control 0x0001" )
	num_SL_binary = 0b0
	$num_SL.to_i.times {|i|
		num_SL_binary |= 1 << i 
	}
	control_map = "0x%04X" % num_SL_binary
	new_file.puts "cc_ca_cong_setting_control_map #{control_map}"	
	$num_SL.to_i.times {|i|
		new_file.puts(
"cc_ca_cong_setting_ccti_timer #{i} #{ccti_timer}
cc_ca_cong_setting_ccti_increase #{i} 1
cc_ca_cong_setting_trigger_threshold #{i} 1
cc_ca_cong_setting_ccti_min #{i} 0" )
	}
	new_file.puts "cc_cct #{generate_cct_simula_llnl()}"
	new_file.close
end

options = Parser.new do |p|
	p.banner = "Tool for generating optimal settings for Congestion Control in OpenSM using mpiGraph\nby Perry Huang (huang32@llnl.gov)\n\n"
	p.version = "opensm-cc-optimizer 1.0 by Perry Huang (huang32@llnl.gov)"
	#p.option :verbose, "enable verbose output"
	p.option :test_all, "use all nodes in fabric", :short => "a"
	#p.option :nodes, "nodes used (default: all)", :default => "node[1-3,57,80]", :short => "n"
	p.option :num_nodes, "number of nodes in partition", :default => "800", :short => "n"
	p.option :partition, "partition name", :default => "partition0", :short => "p"
	p.option :mpiGraph, "mpiGraph location", :default => "~/mpiGraph"
	p.option :config, "local OpenSM conf", :default => "/etc/opensm.conf"
	p.option :optimized_conf, "optimized OpenSM conf output", :default => "opt.conf"
	p.option :sl, "# of service levels", :default => "8"
	p.option :opensm, "OpenSM location", :default => "/usr/sbin/opensm", :short => "d"
end.process!

if(!File.exists?(options[:mpiGraph]) || !File.exists?(options[:config]))
	fail("Missing arguments: either mpiGraph or opensm.conf cannot be found!")
end

if(File.exists?(options[:optimized_conf]))
	fail("File for optimized conf settings already exists!")
end

$partition = options[:partition]
$num_nodes = options[:num_nodes]
$mpiGraph_location = options[:mpiGraph]
$config_location = options[:config]
$optimized_config_location = options[:optimized_conf]
$num_SL = options[:sl]
$opensm_location = options[:opensm]

puts "Using mpiGraph at #{File.expand_path($mpiGraph_location)} with nodes #{$num_nodes}}."
puts "Testing threshold settings..."
threshold = test_threshold(0, 15)
puts "Testing CCTI timer settings..."
ccti_timer = test_ccti_timer(50, 2400)

generate_optimized_conf(threshold, ccti_timer, $optimized_config_location)
puts "Optimized conf file generated at #{$optimized_config_location}"
exit
