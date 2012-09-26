#!/usr/bin/ruby
# Configuration generator script for IB CC Study
# Perry Huang
# huang32@llnl.gov

#require 'colorize'

if(ARGV[0].to_s == "")
	fail("Usage: ./opensm-cc-conf-gen.rb [\# of SL]")
end

$num_SL = ARGV[0].to_i
$current_conf_name = "opensm_hyperion38.conf"
#$current_conf_file = "/etc/opensm.conf"
#$new_conf_file = File.new("opensm_cc.conf", "w")
$new_conf_name = "conf/opensm_cc.conf"
$index = "index"
def generate_cct_simula_optimal()
	retval = String.new
	num_entries = 128

	num_entries.times {|i|
		current = ((i ** 2) * 7) / (1.0 * 106 ** 2)
		current = current.to_f / 0.218
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

def generate_cct_mellanox_default()
	retval = String.new
	num_entries = 128

	num_entries.times {|i|
		current = ((i ** 2) * 7) / (1.0 * 95 ** 2)
		current = current.to_f / 0.218
		entry = "0:" + current.to_i.to_s
		if(i == 0)
			retval = entry
		else
			retval += ","
			retval += entry
		end
	}
	return retval
end

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

def generate_cct_mellanox_llnl()
	retval = String.new
	num_entries = 128

	num_entries.times {|i|
		current = ((i ** 2) * 7) / (1.0 * 95 ** 2)
		current = current.to_f / 0.408
		entry = "0:" + current.to_i.to_s
		if(i == 0)
			retval = entry
		else
			retval += ","
			retval += entry
		end
	}
	return retval
end

def create_cc_settings()
	options = Hash.new
	temp = Array.new

	# Congestion control
	options["congestion_control"] = "TRUE"

	# Key
	options["cc_key"] = "0x0000000000000000"

	# Max outstanding MADs
	options["cc_max_outstanding_mads"] = "500"

	# Control map
	options["cc_sw_cong_setting_control_map"] = "0x1f"

	# Victim mask
	options["cc_sw_cong_setting_victim_mask"] = "0x000000000000000000000000000000000000000000000000001ffffffffe"

	# Credit mask
	options["cc_sw_cong_setting_credit_mask"] = "0x0000000000000000000000000000000000000000000000000000000000000000"

	# Threshold
	temp = ["0x0", "0x1", "0x5", "0x9", "0xc", "0xf"]
	options["cc_sw_cong_setting_threshold"] = temp

	# Minimum packet size
	options["cc_sw_cong_setting_packet_size"] = "1"

	# Credit starvation threshold
	options["cc_sw_cong_setting_credit_starvation_threshold"] = "0x00"

	# Credit starvation return delay
	options["cc_sw_cong_setting_credit_starvation_return_delay"] = "0:0"

	# Marking rate
	temp = ["0x0000", "0x0002", "0x0004", "0x0008", "0x000f", "0x0020", "0x0030", "0x0040", "0x0050"]
	options["cc_sw_cong_setting_marking_rate"] = temp

	# Port control
	options["cc_ca_cong_setting_port_control"] = "0x0001"

	# Control map
	num_SL_binary = 0b0
	$num_SL.times {|i|
		num_SL_binary |= 1 << i 
	}
	control_map = "0x%04X" % num_SL_binary
	options["cc_ca_cong_setting_control_map"] = control_map

	# CCTI_Timer
	temp = ["2", "4", "8", "16", "32", "64", "128", "256", "512", "1024", "2048", "4096", "8192"]
	$num_SL.times {|i|
		options["cc_ca_cong_setting_ccti_timer #{i}"] = temp
	}

	# CCTI_Increase
	$num_SL.times {|i|
		options["cc_ca_cong_setting_ccti_increase #{i}"] = "1"
	}

	# CCTI_Limit
	$num_SL.times {|i|
		options["cc_ca_cong_setting_trigger_threshold #{i}"] = "1"
	}

	# CCTI_Min
	$num_SL.times {|i|
		options["cc_ca_cong_setting_ccti_min #{i}"] = "0"
	}

	# CCT
	#options["cc_cct"] = generate_cct()
	options["cc_cct"] = [generate_cct_mellanox_default(), generate_cct_mellanox_llnl(), generate_cct_simula_optimal(), generate_cct_simula_llnl()]

	return options
end

def print_new_confs(options)
	index = File.open($index, "w")
	count = 0
	#count = options["cc_cct"].count * options["cc_ca_cong_setting_ccti_timer 0"].count * options["cc_sw_cong_setting_marking_rate"].count * options["cc_sw_cong_setting_threshold"].count
	cct_table = options["cc_cct"]
	cct_table.each {|cct|
		options["cc_ca_cong_setting_ccti_timer 0"].each {|timer_0|
			options["cc_sw_cong_setting_marking_rate"].each {|marking_rate|
				options["cc_sw_cong_setting_threshold"].each {|threshold|
					name = String.new
					ext = String.new
					parts = $new_conf_name.split('.')
					name = parts[0]
					ext = parts[1]
					file_name = name + "#{count}." + ext
					`cp #{$current_conf_name} #{file_name}`
					puts "copied current conf to conf file #{count}"
					new_file = File.open("#{file_name}", "a")
					puts "writing CC stuff to conf file #{count}"
					new_file.puts "congestion_control #{options["congestion_control"]}"
					new_file.puts "cc_key #{options["cc_key"]}"
					new_file.puts "cc_max_outstanding_mads #{options["cc_max_outstanding_mads"]}"
					new_file.puts "cc_sw_cong_setting_control_map #{options["cc_sw_cong_setting_control_map"]}"
					new_file.puts "cc_sw_cong_setting_victim_mask #{options["cc_sw_cong_setting_victim_mask"]}"
					new_file.puts "cc_sw_cong_setting_credit_mask #{options["cc_sw_cong_setting_credit_mask"]}"
					new_file.puts "cc_sw_cong_setting_threshold #{threshold}"
					new_file.puts "cc_sw_cong_setting_packet_size #{options["cc_sw_cong_setting_packet_size"]}"
					new_file.puts "cc_sw_cong_setting_credit_starvation_threshold #{options["cc_sw_cong_setting_credit_starvation_threshold"]}"
					new_file.puts "cc_sw_cong_setting_credit_starvation_return_delay #{options["cc_sw_cong_setting_credit_starvation_return_delay"]}"
					new_file.puts "cc_sw_cong_setting_marking_rate #{marking_rate}"
					new_file.puts "cc_ca_cong_setting_port_control #{options["cc_ca_cong_setting_port_control"]}"
					new_file.puts "cc_ca_cong_setting_control_map #{options["cc_ca_cong_setting_control_map"]}"

					$num_SL.times {|i|
						new_file.puts "cc_ca_cong_setting_ccti_timer #{i} #{timer_0}"
						new_file.puts "cc_ca_cong_setting_ccti_increase #{i} #{options["cc_ca_cong_setting_ccti_increase #{i}"]}"
						new_file.puts "cc_ca_cong_setting_trigger_threshold #{i} #{options["cc_ca_cong_setting_trigger_threshold #{i}"]}"
						new_file.puts "cc_ca_cong_setting_ccti_min #{i} #{options["cc_ca_cong_setting_ccti_min #{i}"]}"
					}	
					new_file.puts "cc_cct #{cct}"
					index.puts file_name
					index.puts "cc_sw_cong_setting_threshold #{threshold}"
					index.puts "cc_sw_cong_setting_marking_rate #{marking_rate}"
					index.puts "cc_ca_cong_setting_ccti_timer #{timer_0}"
					index.puts "cc_ca_cong_setting_ccti_increase #{options["cc_ca_cong_setting_ccti_increase 0"]}"
					index.puts "cc_ca_cong_setting_trigger_threshold #{options["cc_ca_cong_setting_trigger_threshold 0"]}"
					index.puts "cc_ca_cong_setting_ccti_min #{options["cc_ca_cong_setting_ccti_min 0"]}"					
					index.puts "cc_cct #{cct}"
					index.puts
					index.puts "################################"
					index.puts
					new_file.close
					count = count + 1
				}	
			}	
		}	
	}

	index.close
end

settings = create_cc_settings()
print_new_confs(settings)

#`./opensm --config opensm_cc1.conf`

# call function to generate variance in cc settings

# call function to loop through opensm config, run benchmarks, and run graphing
