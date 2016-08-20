require 'pi_piper'
require 'lirc'
include PiPiper
$l = LIRC::Client.new
$pwm = PiPiper::Pwm.new pin: 18

def sound(freq, length=1.0/10.0)
  ($pwm).value = 1.0/freq
  $pwm.on
  sleep length
  $pwm.off
end

def read_pincode(pin="1924")
  pos = 0
  pin.split("").each do |num|
    event = $l.next
    event = $l.next while !event.repeat?
    if event.name == "KEY_NUMERIC_"+num
      sound(10, 0.5)
    else
      sound(1, 2)
      return false
    end
  end

  sound(5, 1)
  return true
end

#read_pincode
#puts l.next.to_s while true
while true
  puts $l.to_s
  sleep 1
end
