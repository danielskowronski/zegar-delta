#!/usr/bin/ruby
require 'rubygems'
require 'i2c'
require 'json'
require 'lirc'
require 'pi_piper'
include PiPiper
require  File.dirname(__FILE__)+'/lib/lcd.rb'
require 'socket'

$configFile =File.dirname(__FILE__)+'/alarms.json'

$lcd = Lcd.new
$buzzer = PiPiper::Pwm.new pin: 18
$lirc = LIRC::Client.new
$time = Time.new
$last_alarm = ""

def display_long_message(text, line, timeout)
  $lcd.writeln(text[0,16],line )
  sleep(timeout)

  (0..text.length-16).each do |i|
     $lcd.writeln(text[i,16],line )
     sleep(timeout)
  end
end

def get_ip
  `ifconfig | grep "inet" | awk '{print $2}' | grep -v "127.0.0.1" | grep -v "::" | tac | head -n 1  | gip`.strip+"                   "
end

def dow_matches(definition, current)
  matches = false
  definition.split("").each do |elem|
    if (elem.to_i%7) == (current.to_i%7) then matches=true end
  end
  return matches
end
def should_enable_alarm
  $time = Time.new
  curr_date = $time.strftime("%Y-%m-%d")
  curr_time = $time.strftime("%H:%M")
  curr_dow  = $time.wday.to_s

  file = File.open($configFile, "r")
  alarms = JSON.parse(file.read)

  should_enable = false
  alarms["regular"].each do |alarm|
    if dow_matches(alarm["dow"],curr_dow) && alarm["time"] == curr_time
      should_enable = true
    end
  end

  alarms["special"].each do |alarm|
    if alarm["date"] == curr_date && alarm["time"] == curr_time
      should_enable = true
    end
  end

  alarms["exceptions"].each do |alarm|
    if alarm["date"] == curr_date && alarm["time"] == curr_time
      should_enable = false
    end
  end

  return should_enable
end
def show_clock
  $lcd.writeln($time.strftime("%H:%M:%S   %d/%m"), 0)
  $lcd.writeln(get_ip, 1)
  # above gets all iface IPs, removes lo and reverses (so wlan shound be before eth)
end
def enable_alarm
  snooze_active = false #TODO

  curr_time = $time.strftime("%H:%M")
  curr_date = $time.strftime("%Y-%m-%d")

  # prevents reactivation of alarm after being disabled in less than 1 minute window
  if $last_alarm==curr_date+"_"+curr_time then return end
  $last_alarm=curr_date+"_"+curr_time

  $lcd.writeln("ALARM -- "+curr_time, 0)

  val = 0.01
  pin = rand(100000..999999).to_s
  pin_disp = pin.dup
  pin_pos_next = 0

  while true
    val += 0.01
    if val > 1.2 then val=0.01 end
    $buzzer.value = val
    $lcd.writeln("PIN   -- "+pin_disp, 1)

    begin
      Timeout::timeout(0.1) do
        event = $lirc.next
        event = $lirc.next while !event.repeat?
        if event.name == "KEY_NUMERIC_"+pin[pin_pos_next]
          pin_disp[pin_pos_next]="#"
          pin_pos_next = pin_pos_next+1
        else
          pin_pos_next=0
          pin_disp=pin
        end
      end
    rescue Timeout::Error
    end

    if pin_pos_next >= 6
      $buzzer.value = 0
      return
    end
  end
end
def worker
  $time = Time.new
  begin
    if should_enable_alarm
      enable_alarm
      show_clock #after enable_alarm closed show clock (bypass for alarm rerunning)
    else
      show_clock
    end
  rescue Exception => ex
    $buzzer.value = 0.5
    $lcd.writeln("! worker crashed",0 )
    display_long_message("#{ex.class} - #{ex.message}",1,0.2)
  end
end

$lcd.writeln("zegar-delta v0.2",0)
$lcd.writeln(get_ip,1 )
sleep(5)

while true
  worker
  sleep(0.25)
end
