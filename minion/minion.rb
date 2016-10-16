#!/usr/bin/ruby
require 'rubygems'
require 'i2c'
require 'json'
require 'lirc'
require 'socket'
require 'w1temp'
require 'pi_piper'
include PiPiper
require  File.dirname(__FILE__)+'/lib/lcd.rb'

VER="0.6"
$ENGMODE=true

$configFile =File.dirname(__FILE__)+'/alarms.json'
$lcd = Lcd.new
$buzzer = PiPiper::Pwm.new pin: 18
$lirc = LIRC::Client.new
$time = Time.new
$last_alarm = ""
$last_hashum = "null"
$error_count = 0
$current_second_line_id = 0
$current_remote433_status = 0
$last_ir_command = "null"

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
  matches
end
def time_matches(definition, current)
  matches = false
  if definition == current then matches=true end
  if "0"+definition == current then matches=true end
  matches
end
def should_enable_alarm
  return true
  $time = Time.new
  curr_date = $time.strftime("%Y-%m-%d")
  curr_time = $time.strftime("%H:%M")
  curr_dow  = $time.wday.to_s

  file = File.open($configFile, "r")
  alarms = JSON.parse(file.read)

  should_enable = false
  alarms["regular"].each do |alarm|
    if dow_matches(alarm["dow"],curr_dow) && time_matches(alarm["time"],curr_time)
      should_enable = true
    end
  end

  alarms["special"].each do |alarm|
    if alarm["date"] == curr_date && time_matches(alarm["time"],curr_time)
      should_enable = true
    end
  end

  alarms["exceptions"].each do |alarm|
    if alarm["date"] == curr_date && time_matches(alarm["time"],curr_time)
      should_enable = false
    end
  end

  return should_enable
end

def second_line
     if $current_second_line_id==0 then return "na polu "+Temperature.new.reading.round(1).to_s+"'C                   "
  elsif $current_second_line_id==1 then return `echo -n "mem free: "; free -h | head -2 | tail -1  | awk '{print $4}'`.strip+"                   "
  elsif $current_second_line_id==2 then return "cpu "+`vcgencmd measure_temp`.strip+"                   "
  elsif $current_second_line_id==3 then return  get_ip
  else return "dupa------------------------------------" end
end
def show_clock
  $lcd.writeln($time.strftime("%H:%M:%S   %d/%m"), 0)
  $lcd.writeln(second_line, 1)
end

def enable_alarm
  curr_time = $time.strftime("%H:%M")
  curr_date = $time.strftime("%Y-%m-%d")

  print "AUDIT Started alarm procedure for #{curr_time}\n"

  # prevents reactivation of alarm after being disabled in less than 1 minute window
  if $last_alarm==curr_date+"_"+curr_time then return end
  $last_alarm=curr_date+"_"+curr_time

  $lcd.writeln("ALARM  -- "+$time.strftime("%H:%M")+"        ", 0)

  val = 0.01
  pin = rand(100000..999999).to_s
  pin_disp = pin.dup
  pin_pos_next = 0

  while true
    val += 0.01
    if val > 1.2 then val=0.01 end
    $buzzer.value = val
    $lcd.writeln("PIN    -- "+pin_disp, 1)

    try_count=0
    this_iter_ir = $last_ir_command

    if this_iter_ir.index("KEY_CHANNEL")==0
      snooze_countdown = 9*60*1000 #9 minutes
      $buzzer.value = 0
      while snooze_countdown>0
        snooze_display = ""+(snooze_countdown/60000).to_s+"m "+((snooze_countdown%60000)/1000).to_s+"s"+"              "
        thr = Thread.new {
          $lcd.writeln("SNOOZE -- "+snooze_display+"   ", 1)
        }
        sleep(0.2)
        snooze_countdown-=200
      end

      # command was not changed during snooze
      if this_iter_ir==$last_ir_command then  $last_ir_command = "null" end

    end

    sleep (0.2)

    if this_iter_ir == "KEY_NUMERIC_"+pin[pin_pos_next]
      pin_disp[pin_pos_next]="#"
      pin_pos_next = pin_pos_next+1
    elsif this_iter_ir != "null"
      pin_pos_next=0
      pin_disp=pin.dup
      try_count+=1
    end

    # command was not changed during parsing
    if this_iter_ir==$last_ir_command then  $last_ir_command = "null" end

    if pin_pos_next >= 6
      $buzzer.value = 0
      print "AUDIT Alarm successfully disabled by user; try_count=#{try_count}\n"
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
    if $ENGMODE then raise ex end #engineering mode
    if ex.message == "SIGTERM" then raise ex end #handle normal exit / service stop

    $buzzer.value = 0.5
    $lcd.writeln("! worker crashed",0 )
    display_long_message("#{ex.class} - #{ex.message}",1,0.2)
    print "CRASH #{ex.class} - #{ex.message} \n"

    $error_count+=1
    if $error_count > 2 then raise ex end
  end
end
def audit_alarms
  curr_hashsum = `sha256sum #{$configFile}`.strip
  if curr_hashsum!=$last_hashum
    print "AUDIT Hashsum changed: #{$last_hashum} -> #{curr_hashsum} \n"
    file = File.open($configFile, "r")
    print "AUDIT Current file: "+JSON.generate(JSON.parse(file.read))+"\n"
    $last_hashum=curr_hashsum
  end
end

$time = Time.new
print "=======================================================================================================\n"
print "INFO  Minion version #{VER} started at #{$time.strftime('%Y-%m-%d %H:%M')} with best IP #{get_ip}\n"

$lcd.writeln("zegar-delta #{VER}",0)
if !$ENGMODE then
  $buzzer.value = 0.5
  $lcd.writeln("zegar-delta #{VER}",0)
  $lcd.writeln(get_ip, 1)
  sleep(3)
  $buzzer.value = 0
end

thr = Thread.new do
  $lirc.each do |event|
   if event.repeat? then next end
   $last_ir_command = event.name

    if $ENGMODE then print "DEBUG IR: "+event.name+"\n" end

    if event.name=="KEY_FORWARD"
      $current_second_line_id = $current_second_line_id+1
      if $current_second_line_id>3 then $current_second_line_id=0 end
    elsif event.name == "KEY_PREVIOUS"
      $current_second_line_id = $current_second_line_id-1
      if $current_second_line_id<0 then $current_second_line_id=3 end
    elsif event.name == "KEY_EQUAL"
      if $current_remote433_status==0
        $current_remote433_status=1
        print "AUDIT 433MHz command: "+`send433 11111 3 1`
      else
        $current_remote433_status=0
        print "AUDIT 433MHz command: "+`send433 11111 3 0`
      end
    end
  end
end


while true
  audit_alarms
  worker
  sleep(0.05)
end

thr.raise "stop"
