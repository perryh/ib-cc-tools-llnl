#!/usr/bin/ruby
# Configuration testing script for IB CC Study
# Perry Huang
# huang32@llnl.gov

#if(ARGV[0].to_s == "")
# fail("Usage: ./opensm-cc-tester-test2.rb [dir]")
#end

#$dir = ARGV[0]
$dir = "conf_reoptimize3/"
$result_name = "results.csv"

result_file = File.open($result_name, "w")

send_avg = ""
recv_avg = ""
result_file.puts "conf_file,threshold,ccti_timer,send_avg,recv_avg"
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
  puts "Running mpigraph"
  retval = `srun -n 7 -N 7 -ppcongest /opt/mpigraph-mvapich-gnu-1.0/bin/mpigraph`
  retval = retval.split
  send_avg = retval[39]
  recv_avg = retval[116]


  #retval = retval.sub("\n", " ")
  #retval = retval.sub("\n", "")
  #retval = retval.split(" ")
  #receive_A = retval[1]
  #receive_B = retval[0]
  #result_file.puts "#{conf},#{receive_A},#{receive_B}"
  #marking_rate = `cat #{$dir}#{conf} | grep "cc_sw_cong_setting_marking_rate"`
  #marking_rate = marking_rate.split 
  threshold = `cat #{$dir}#{conf} | grep "cc_sw_cong_setting_threshold"`
  threshold = threshold.split
  ccti_timer = `cat #{$dir}#{conf} | grep "cc_ca_cong_setting_ccti_timer 1"`
  ccti_timer = ccti_timer.split


  result_file.puts "#{conf},#{threshold[1]},#{ccti_timer[2]},#{send_avg},#{recv_avg}"
  puts "Results for #{conf} saved to #{$result_name}"

  Process.kill("SIGKILL", opensm_process_id)
  puts "Process #{opensm_process_id} killed"
  result_file.close
end

`mv results.csv results_test3_3dgraph_mpigraph.csv`