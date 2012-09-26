export LST_SESSION=$$
lst new_session -f perry_test
lst add_group send_E 192.168.127.72@o2ib
lst add_group send_F 192.168.127.73@o2ib
lst add_group send_G 192.168.127.74@o2ib
lst add_group send_H 192.168.127.75@o2ib
lst add_group receive_A 192.168.127.[68,69]@o2ib
lst add_group receive_B 192.168.127.[70,71]@o2ib
lst add_group receive_C 192.168.127.[68,70]@o2ib
lst add_group receive_D 192.168.127.[69,71]@o2ib
lst add_batch SEND_E
lst add_test --batch SEND_E --from send_E --to receive_A --concurrency 8 brw write check=simple size=1M
lst run SEND_E
lst add_batch SEND_F
lst add_test --batch SEND_F --from send_F --to receive_B --concurrency 8 brw write check=simple size=1M
lst run SEND_F
lst add_batch SEND_G
lst add_test --batch SEND_G --from send_G --to receive_C --concurrency 8 brw write check=simple size=1M
lst run SEND_G
lst add_batch SEND_H
lst add_test --batch SEND_H --from send_H --to receive_D --concurrency 8 brw write check=simple size=1M
lst run SEND_H
lst stat --bw send_E send_F send_G send_H & sleep 30
kill $!
lst end_session