require 'pi_piper'
include PiPiper

pwm = PiPiper::Pwm.new pin: 18
pwm.value=0
