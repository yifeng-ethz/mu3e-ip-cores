#

post_message "I \[pre_flow\] git rev [exec git rev-parse HEAD]"

post_message "I \[pre_flow\] exec make pre_flow"
catch { exec -ignorestderr -- make pre_flow }
