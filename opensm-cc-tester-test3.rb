#!/usr/bin/ruby
# Configuration testing script for IB CC Study
# Perry Huang
# huang32@llnl.gov

if(ARGV[0].to_s == "")
	fail("Usage: ./opensm-cc-tester-test3.rb [dir]")
end

$dir = ARGV[0]

$result_name = "results.csv"

result_file = File.open($result_name, "w")

averages = Array.new
result_file.puts "conf_file,send_37,send_38,send_39,send_43,send_44,receive_41,receive_42"
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
	#retval = `sh congest.sh | grep "[R]" | awk '{if (cnt % 2 == 0) sum1+=$9;if (cnt % 2 == 1) sum2+=$9;cnt++} END {print sum1/((cnt-1)/2); print sum2/((cnt-1)/2)}'`
	retval = `sh congest_test3.sh | grep -E "\[R\]|\[W\]"`
	retval = retval.sub("SESSION: perry_test TIMEOUT: 300 FORCE: Yes\n", "")
	retval = retval.split("\n")
	count = 1
	iterations = 0
	send_37 = 0.0
	send_38 = 0.0
	send_39 = 0.0
	#send_40 = 0.0
	send_43 = 0.0
	send_44 = 0.0
	receive_41 = 0.0
	receive_42 = 0.0
	retval.each {|line|
		line_split = line.split
		term = line_split[8]
		if(count % 14 == 2)
			send_37 += Float(term)
		elsif(count % 14 == 4)
			send_38 += Float(term)
		elsif(count % 14 == 6)
			send_39 += Float(term)
		#elsif(count % 14 == 8)
		#	send_40 += Float(term)
		elsif(count % 14 == 8)
			send_43 += Float(term)
		elsif(count % 14 == 10)
			send_44 += Float(term)
		elsif(count % 14 == 11)
			receive_41 += Float(term)
		elsif(count % 14 == 13)
			receive_42 += Float(term)
			iterations += 1
		end
		
		count += 1
	}

	send_37 /= iterations
	send_38 /= iterations
	send_39 /= iterations
	#send_40 /= iterations
	send_43 /= iterations
	send_44 /= iterations
	receive_41 /= iterations
	receive_42 /= iterations



	puts "Running congest.sh"
	#retval = retval.sub("\n", " ")
	#retval = retval.sub("\n", "")
	#retval = retval.split(" ")
	#receive_A = retval[1]
	#receive_B = retval[0]
	#result_file.puts "#{conf},#{receive_A},#{receive_B}"
	#result_file.puts "#{conf},#{send_37},#{send_38},#{send_39},#{send_40},#{send_43},#{send_44},#{receive_41},#{receive_42}"
	result_file.puts "#{conf},#{send_37},#{send_38},#{send_39},#{send_43},#{send_44},#{receive_41},#{receive_42}"

	puts "Results for #{conf} saved to #{$result_name}"

	Process.kill("SIGKILL", opensm_process_id)
	puts "Process #{opensm_process_id} killed"
	result_file.close
end
