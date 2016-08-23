class Lcd

    require 'i2c/i2c'
    require 'i2c/backends/i2c-dev'

#   4bit bits for operations:
#   d7,d6,d5,d4,bl,en,rw,rs
#   rs = 0-command, 1-data
#   rw = 0-write, 1-read
#   en = 0-disabled, 1-enabled # lcd data bit pulse
#   4bit - two halves, upper four bits first.

    def initialize
        @i2c = I2C.create('/dev/i2c-1')
        @addr = 0x27
        @displaycontrol = 0x0
        @functionset = 0x0
        @entrymode = 0x0
        @backlight = LCD_BACKLIGHT

        # http://elm-chan.org/docs/lcd/hd44780_e.html    @ 4bit-mode
        3.times do
            command(0x03) # Special Function Set
            sleep(0.0001)
        end
        sleep(0.0005)
        command(0x02)

        # Now the display is set in 4bit mode.
        # Proceeding with display configuration
        @displaycontrol = LCD_DISPLAYCONTROL | LCD_DISPLAYON | LCD_CURSOROFF
        @functionset = LCD_FUNCTIONSET | LCD_2LINE | LCD_5x8DOTS | LCD_4BITMODE
        @entrymode = LCD_ENTRYMODESET | LCD_ENTRYLEFT
        command(@functionset)
        command(@displaycontrol)
        command(@entrymode)
        clear()

        sleep(0.005)
    end

    def clear
        command(LCD_CLEARDISPLAY)
        sleep(0.2)
    end

    def home
        command(LCD_RETURNHOME)
        sleep(0.2)
    end

    def entryLeft
        @entrymode |= LCD_ENTRYLEFT
        command(@entrymode)
    end

    def entryRight
        @entrymode &= ~LCD_ENTRYLEFT
    end

    def shiftIncrement
        @entrymode |= LCD_ENTRYSHIFTINCREMENT
    end

    def shiftDecrement
        @entrymode &= ~LCD_ENTRYSHIFTINCREMENT
    end

    def cursor
        @displaycontrol |= LCD_CURSORON
        command(@displaycontrol)
    end

    def noCursor
        @displaycontrol &= ~LCD_CURSORON
        command(@displaycontrol)
    end

    def setCursor(col,row)
        row_offsets = %w(0x00,0x40,0x14,0x54)
        command(LCD_SETDDRAMADDR | (col + row_offsets[row].to_i)) unless row > 2
    end

    def cursorMoveLeft
        command(LCD_CURSORSHIFT | LCD_MOVELEFT)
    end

    def cursorMoveRight
        command(LCD_CURSORSHIFT | LCD_MOVERIGHT)
    end

    def displayMoveLeft
        command(LCD_CURSORSHIFT | LCD_DISPLAYMOVE | LCD_MOVELEFT)
    end

    def displayMoveRight
        command(LCD_CURSORSHIFT | LCD_DISPLAYMOVE | LCD_MOVERIGHT)
    end

    def display
        @displaycontrol |= LCD_DISPLAYON
        command(@displaycontrol)
    end

    def noDisplay
        @displaycontrol &= ~LCD_DISPLAYON
        command(@displaycontrol)
    end

    def blink
        @displaycontrol |= LCD_BLINKON
        command(@displaycontrol)
    end

    def noBlink
        @displaycontrol &= ~LCD_BLINKON
        command(@displaycontrol)
    end

    def autoscroll
        @entrymode |= LCD_ENTRYSHIFTINCREMENT
        command(@entrymode)
    end

    def noAutoscroll
        @entrymode &= ~LCD_ENTRYSHIFTINCREMENT
        command(@entrymode)
    end

    def leftToRight
        @entrymode |= LCD_ENTRYLEFT
        command(@entrymode)
    end

    def rightToLeft
        @entrymode &= ~LCD_ENTRYLEFT
        command(@entrymode)
    end

    def backlight
        @backlight = LCD_BACKLIGHT
        command(0)
    end

    def noBacklight
        @backlight = 0
        command(0)
    end

    def command(data)
        w4b(data,0x0)
    end

    def writeln(data, line=0)
        line > 0 ? command(0xc0) : command(0x80)
        data.each_char do |c|
            write_chr(c.ord)
        end
    end

    def write(data)
        data.each_char do |c|
           write_chr(c.ord)
        end
    end

    def write_chr(data)
        w4b(data,0x1)   # mode = 1 - set RS to 1 = write data not cmd
    end

    def w4b(data,mode)
        data_high = data & 0xf0
        data_low = (data << 4) & 0xf0
        #p "Sending #{data} as H:#{data_high} L:#{data_low}"
        pulse(data_high | mode)
        pulse(data_low | mode)
    end

    def pulse(data)
        @i2c.write(@addr, data | (1<<2) | @backlight)
        sleep(0.0005)
        @i2c.write(@addr, data & ~(1<<2) | @backlight)
        sleep(0.0001)
    end

    # commands
    LCD_CLEARDISPLAY = 0x01
    LCD_RETURNHOME = 0x02
    LCD_ENTRYMODESET = 0x04
    LCD_DISPLAYCONTROL = 0x08
    LCD_CURSORSHIFT = 0x10
    LCD_FUNCTIONSET = 0x20
    LCD_SETCGRAMADDR = 0x40
    LCD_SETDDRAMADDR = 0x80

    # flags for display entry mode
    LCD_ENTRYRIGHT = 0x00
    LCD_ENTRYLEFT = 0x02
    LCD_ENTRYSHIFTINCREMENT = 0x01
    LCD_ENTRYSHIFTDECREMENT = 0x00

    # flags for display on/off control
    LCD_DISPLAYON = 0x04
    LCD_DISPLAYOFF = 0x00
    LCD_CURSORON = 0x02
    LCD_CURSOROFF = 0x00
    LCD_BLINKON = 0x01
    LCD_BLINKOFF = 0x00

    # flags for display/cursor shift
    LCD_DISPLAYMOVE = 0x08
    LCD_CURSORMOVE = 0x00
    LCD_MOVERIGHT = 0x04
    LCD_MOVELEFT = 0x00

    # flags for function set
    LCD_8BITMODE = 0x10
    LCD_4BITMODE = 0x00
    LCD_2LINE = 0x08
    LCD_1LINE = 0x00
    LCD_5x10DOTS = 0x04
    LCD_5x8DOTS = 0x00

    # flags for backlight control
    LCD_BACKLIGHT = 0x08
    LCD_NOBACKLIGHT = 0x00
end
