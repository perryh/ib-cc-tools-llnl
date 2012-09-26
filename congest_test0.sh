export LST_SESSION=$$
lst new_session -f perry_test
lst add_group send_A 192.168.127.[70-71,74-75]@o2ib
lst add_group send_B 192.168.127.69@o2ib
lst add_group receive_A 192.168.127.73@o2ib
lst add_group receive_B 192.168.127.72@o2ib
lst add_batch CONGEST
lst add_test --batch CONGEST --from send_A --to receive_A --concurrency 16 brw write check=simple size=1M
lst run CONGEST
lst add_batch VICTIM
lst add_test --batch VICTIM --from send_B --to receive_B --concurrency 16 brw write check=simple size=1M
lst run VICTIM
lst stat --bw receive_A receive_B & sleep 30
kill $!
lst end_session
