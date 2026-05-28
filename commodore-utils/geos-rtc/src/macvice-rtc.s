.setcpu "6502"

LOAD_ADDRESS = $0400

CPU_DATA = $0001
C128_CONFIG = $ff00
IO_IN = $35
C128_IO_IN = $7e

CIA1_TOD10 = $dc08
CIA1_TODSEC = $dc09
CIA1_TODMIN = $dc0a
CIA1_TODHR = $dc0b
CIA2_PB = $dd01
CIA2_DDRB = $dd03

GEOS_YEAR = $8516
GEOS_MONTH = $8517
GEOS_DAY = $8518
GEOS_HOUR = $8519
GEOS_MINUTES = $851a
GEOS_SECONDS = $851b
ENTER_DESKTOP = $c22c

SDA = $01
SCL = $02
DS1307_WRITE = $d0
DS1307_READ = $d1

.segment "LOADADDR"
.word LOAD_ADDRESS

.segment "CODE"

.proc main
        sei
.ifdef TARGET_C128
        lda C128_CONFIG
        pha
        lda #C128_IO_IN
        sta C128_CONFIG
.else
        lda CPU_DATA
        pha
        lda #IO_IN
        sta CPU_DATA
.endif

        jsr read_ds1307
        bcs done
        jsr install_time

done:
.ifdef TARGET_C128
        pla
        sta C128_CONFIG
.else
        pla
        sta CPU_DATA
.endif
        cli
        jmp ENTER_DESKTOP
.endproc

.proc install_time
        lda ds_seconds
        and #$7f
        sta ds_seconds
        jsr bcd_to_bin
        sta GEOS_SECONDS

        lda ds_minutes
        jsr bcd_to_bin
        sta GEOS_MINUTES

        lda ds_hour
        and #$3f
        sta ds_hour
        jsr bcd_to_bin
        sta GEOS_HOUR

        lda ds_day
        jsr bcd_to_bin
        sta GEOS_DAY

        lda ds_month
        and #$1f
        sta ds_month
        jsr bcd_to_bin
        sta GEOS_MONTH

        lda ds_year
        jsr bcd_to_bin
        sta GEOS_YEAR

        lda ds_hour
        cmp #$13
        bcc store_tod_hour
        sed
        sec
        sbc #$12
        cld
        ora #$80
store_tod_hour:
        sta CIA1_TODHR
        lda ds_minutes
        sta CIA1_TODMIN
        lda ds_seconds
        sta CIA1_TODSEC
        lda #0
        sta CIA1_TOD10
        rts
.endproc

.proc read_ds1307
        jsr i2c_stop
        jsr i2c_start
        lda #DS1307_WRITE
        jsr i2c_write_byte
        bcs failed
        lda #0
        jsr i2c_write_byte
        bcs failed
        jsr i2c_start
        lda #DS1307_READ
        jsr i2c_write_byte
        bcs failed

        lda #0
        sta reg_index
read_loop:
        lda reg_index
        cmp #6
        beq read_last
        lda #0
        sta ack_value
        jsr i2c_read_byte
        jmp store_register
read_last:
        lda #1
        sta ack_value
        jsr i2c_read_byte
store_register:
        ldx reg_index
        sta ds_seconds,x
        inc reg_index
        lda reg_index
        cmp #7
        bne read_loop

        jsr i2c_stop
        clc
        rts

failed:
        jsr i2c_stop
        sec
        rts
.endproc

.proc i2c_start
        jsr release_sda
        jsr release_scl
        jsr pull_sda_low
        jsr pull_scl_low
        rts
.endproc

.proc i2c_stop
        jsr pull_sda_low
        jsr release_scl
        jsr release_sda
        rts
.endproc

.proc i2c_write_byte
        sta current_byte
        ldx #8
bit_loop:
        asl current_byte
        bcs one_bit
        jsr pull_sda_low
        jmp clock_bit
one_bit:
        jsr release_sda
clock_bit:
        jsr release_scl
        jsr pull_scl_low
        dex
        bne bit_loop

        jsr release_sda
        jsr release_scl
        lda CIA2_PB
        and #SDA
        pha
        jsr pull_scl_low
        pla
        beq acked
        sec
        rts
acked:
        clc
        rts
.endproc

.proc i2c_read_byte
        lda #0
        sta current_byte
        ldx #8
bit_loop:
        asl current_byte
        jsr release_sda
        jsr release_scl
        lda CIA2_PB
        and #SDA
        beq zero_bit
        inc current_byte
zero_bit:
        jsr pull_scl_low
        dex
        bne bit_loop

        lda ack_value
        bne send_nack
        jsr pull_sda_low
        jmp ack_clock
send_nack:
        jsr release_sda
ack_clock:
        jsr release_scl
        jsr pull_scl_low
        jsr release_sda
        lda current_byte
        rts
.endproc

.proc release_sda
        lda CIA2_PB
        ora #SDA
        sta CIA2_PB
        lda CIA2_DDRB
        and #$ff-SDA
        sta CIA2_DDRB
        jsr i2c_delay
        rts
.endproc

.proc pull_sda_low
        lda CIA2_PB
        and #$ff-SDA
        sta CIA2_PB
        lda CIA2_DDRB
        ora #SDA
        sta CIA2_DDRB
        jsr i2c_delay
        rts
.endproc

.proc release_scl
        lda CIA2_PB
        ora #SCL
        sta CIA2_PB
        lda CIA2_DDRB
        ora #SCL
        sta CIA2_DDRB
        jsr i2c_delay
        rts
.endproc

.proc pull_scl_low
        lda CIA2_PB
        and #$ff-SCL
        sta CIA2_PB
        lda CIA2_DDRB
        ora #SCL
        sta CIA2_DDRB
        jsr i2c_delay
        rts
.endproc

.proc i2c_delay
        nop
        nop
        nop
        nop
        rts
.endproc

.proc bcd_to_bin
        pha
        and #$0f
        sta low_nibble
        pla
        lsr
        lsr
        lsr
        lsr
        sta high_nibble
        asl
        asl
        asl
        clc
        adc high_nibble
        adc high_nibble
        clc
        adc low_nibble
        rts
.endproc

.segment "DATA"
ds_seconds: .byte 0
ds_minutes: .byte 0
ds_hour: .byte 0
ds_weekday: .byte 0
ds_day: .byte 0
ds_month: .byte 0
ds_year: .byte 0
reg_index: .byte 0
ack_value: .byte 0
current_byte: .byte 0
low_nibble: .byte 0
high_nibble: .byte 0
