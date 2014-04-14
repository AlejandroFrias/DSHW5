on run argv
  tell application "Terminal"
      activate
      tell application "System Events"
          keystroke "t" using command down # new tab
          keystroke "ssh "& item 1 from argv & "@ash.cs.hmc.edu"
          key code 36 # press enter
          keystroke "cd /home/"& item 1 from argv &"/courses/DSHW5"
          key code 36 # press enter
          keystroke "erl -noshell -run key_value_node main " & item 1 from argv & " node1"
          key code 36 # press enter

          keystroke "t" using command down # new tab
          keystroke "ssh "& item 1 from argv & "@birnam.cs.hmc.edu"
          key code 36 # press enter
          keystroke "cd /home/"& item 1 from argv &"/courses/DSHW5"
          key code 36 # press enter
          keystroke "sleep 2"
          key code 36 # press enter
          keystroke "erl -noshell -run key_value_node main " & item 1 from argv & " node2 node1@ash"
          key code 36 # press enter

          keystroke "t" using command down # new tab
          keystroke "ssh "& item 1 from argv & "@clover.cs.hmc.edu"
          key code 36 # press enter
          keystroke "cd /home/"& item 1 from argv &"/courses/DSHW5"
          key code 36 # press enter
          keystroke "sleep 4"
          key code 36 # press enter
          keystroke "erl -noshell -run key_value_node main " & item 1 from argv & " node3 node1@ash"
          key code 36 # press enter

          keystroke "t" using command down # new tab
          keystroke "ssh "& item 1 from argv & "@dittany.cs.hmc.edu"
          key code 36 # press enter
          keystroke "cd /home/"& item 1 from argv &"/courses/DSHW5"
          key code 36 # press enter
          keystroke "sleep 6"
          key code 36 # press enter
          keystroke "erl -noshell -run key_value_node main " & item 1 from argv & " node4 node1@ash"
          key code 36 # press enter

          keystroke "t" using command down # new tab
          keystroke "ssh "& item 1 from argv & "@elm.cs.hmc.edu"
          key code 36 # press enter
          keystroke "cd /home/"& item 1 from argv &"/courses/DSHW5"
          key code 36 # press enter
          keystroke "sleep 8"
          key code 36 # press enter
          keystroke "erl -noshell -run key_value_node main " & item 1 from argv & " node5 node1@ash"
          key code 36 # press enter

          keystroke "t" using command down # new tab
          keystroke "ssh "& item 1 from argv & "@fir.cs.hmc.edu"
          key code 36 # press enter
          keystroke "cd /home/"& item 1 from argv &"/courses/DSHW5"
          key code 36 # press enter
          keystroke "sleep 10"
          key code 36 # press enter
          keystroke "erl -noshell -run key_value_node main " & item 1 from argv & " node6 node1@ash"
          key code 36 # press enter

          keystroke "t" using command down # new tab
          keystroke "ssh "& item 1 from argv & "@godswood.cs.hmc.edu"
          key code 36 # press enter
          keystroke "cd /home/"& item 1 from argv &"/courses/DSHW5"
          key code 36 # press enter
          keystroke "sleep 12"
          key code 36 # press enter
          keystroke "erl -noshell -run key_value_node main " & item 1 from argv & " node7 node1@ash"
          key code 36 # press enter

          keystroke "t" using command down # new tab
          keystroke "ssh "& item 1 from argv & "@heath.cs.hmc.edu"
          key code 36 # press enter
          keystroke "cd /home/"& item 1 from argv &"/courses/DSHW5"
          key code 36 # press enter
          keystroke "sleep 14"
          key code 36 # press enter
          keystroke "erl -noshell -run key_value_node main " & item 1 from argv & " node8 node1@ash"
          key code 36 # press enter

          keystroke "t" using command down # new tab
          keystroke "ssh "& item 1 from argv & "@lavender.cs.hmc.edu"
          key code 36 # press enter
          keystroke "cd /home/"& item 1 from argv &"/courses/DSHW5"
          key code 36 # press enter
          keystroke "sleep 16"
          key code 36 # press enter
          keystroke "erl -noshell -run key_value_node main " & item 1 from argv & " node9 node1@ash"
          key code 36 # press enter

      end tell
  end tell
end run
