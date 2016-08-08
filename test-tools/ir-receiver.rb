require 'lirc'
l = LIRC::Client.new
puts l.next.to_s while true
