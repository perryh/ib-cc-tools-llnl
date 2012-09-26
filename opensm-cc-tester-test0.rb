#!/usr/bin/ruby
# Configuration testing script for IB CC Study
# Perry Huang
# huang32@llnl.gov

if(ARGV[0].to_s == "")
	fail("Usage: ./opensm-cc-tester.rb [dir]")
end

$dir = ARGV[0]

$result_name = "results.csv"

result_file = File.open($result_name, "w")

averages = Array.new
result_file.puts "conf_file,receive_A,receive_B"
result_file.close
Dir.foreach($dir) do |conf|
	if(conf == '.' || conf == '..') then
		next
	end
	result_file = File.open($result_name, "a")
	opensm_process_id = fork do
		exec '/home/huang32/opensm', "--conf", "#{$dir}/#{conf}"
	end

	puts "Loaded new process for opensm with #{conf} and process id #{opensm_process_id}"
	puts "Waiting for 5 seconds for opensm to finish loading"
	sleep 5
	retval = `sh congest.sh | grep "[R]" | awk '{if (cnt % 2 == 0) sum1+=$9;if (cnt % 2 == 1) sum2+=$9;cnt++} END {print sum1/((cnt-1)/2); print sum2/((cnt-1)/2)}'`
	puts "Running congest.sh"
	retval = retval.sub("\n", " ")
	retval = retval.sub("\n", "")
	retval = retval.split(" ")
	receive_A = retval[1]
	receive_B = retval[0]
	result_file.puts "#{conf},#{receive_A},#{receive_B}"
	puts "Results for #{conf} saved to #{$result_name}"

	Process.kill("SIGKILL", opensm_process_id)
	puts "Process #{opensm_process_id} killed"
	result_file.close
end
