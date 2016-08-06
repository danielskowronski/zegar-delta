require 'pi_piper'
include PiPiper

def simple_alarm
  pwm = PiPiper::Pwm.new pin: 18

  val = 0.01
  while val<= 1.2
    pwm.value = val
    sleep 1.0/10
    val+=0.01
  end

  pwm.off
end

while true
  simple_alarm
end
