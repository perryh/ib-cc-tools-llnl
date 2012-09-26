export LST_SESSION=$$
lst new_session -f perry_test
lst add_group send_37 192.168.127.68@o2ib
lst add_group send_38 192.168.127.69@o2ib
lst add_group send_39 192.168.127.70@o2ib
#lst add_group send_40 192.168.127.71@o2ib
lst add_group send_43 192.168.127.74@o2ib
#lst add_group send_44 192.168.127.75@o2ib
lst add_group receive_41 192.168.127.72@o2ib
lst add_group receive_42 192.168.127.73@o2ib
lst add_batch CONGEST_38
lst add_test --batch CONGEST_38 --from send_38 --to receive_42 --concurrency 16 brw write check=simple size=1M
lst run CONGEST_38
lst add_batch CONGEST_39
lst add_test --batch CONGEST_39 --from send_39 --to receive_42 --concurrency 16 brw write check=simple size=1M
lst run CONGEST_39
#lst add_batch CONGEST_40
#lst add_test --batch CONGEST_40 --from send_40 --to receive_42 --concurrency 16 brw write check=simple size=1M
#lst run CONGEST_40
lst add_batch CONGEST_43
lst add_test --batch CONGEST_43 --from send_43 --to receive_42 --concurrency 16 brw write check=simple size=1M
lst run CONGEST_43
#lst add_batch CONGEST_44
#lst add_test --batch CONGEST_44 --from send_44 --to receive_42 --concurrency 16 brw write check=simple size=1M
#lst run CONGEST_44
lst add_batch VICTIM_37
lst add_test --batch VICTIM_37 --from send_37 --to receive_41 --concurrency 16 brw write check=simple size=1M
lst run VICTIM_37
lst stat --bw send_37 send_38 send_39 send_43 receive_41 receive_42 & sleep 30
#lst stat --bw receive_41 receive_42 & sleep 30
kill $!
lst end_session
