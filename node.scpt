on run argv
  tell application "Terminal"
      activate
      tell application "System Events"
          keystroke "t" using command down # new tab
          keystroke "ssh "& item 1 from argv & "@" & item 2 of argv & ".cs.hmc.edu"
          key code 36 # press enter
          keystroke "cd /home/"& item 1 from argv &"/courses/DSHW5"
          key code 36 # press enter
          keystroke "erl -noshell -run key_value_node main " & item 3 of argv & " " & item 4 of argv & " " & item 5 of argv
          key code 36 # press enter
      end tell
  end tell
end run
