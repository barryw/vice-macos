CC65 ?= /Users/barry/Git/cc65/bin
CA65 := $(CC65)/ca65
LD65 := $(CC65)/ld65
BUILD := build

all: $(BUILD)/macvice-rtc64.prg $(BUILD)/macvice-rtc128.prg $(BUILD)/macvice-rtc64.grc $(BUILD)/macvice-rtc128.grc

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/macvice-rtc64.o: src/macvice-rtc.s | $(BUILD)
	$(CA65) --cpu 6502 -D TARGET_C64 -o $@ $<

$(BUILD)/macvice-rtc128.o: src/macvice-rtc.s | $(BUILD)
	$(CA65) --cpu 6502 -D TARGET_C128 -o $@ $<

$(BUILD)/macvice-rtc64.prg: $(BUILD)/macvice-rtc64.o src/geos-prg.cfg
	$(LD65) -C src/geos-prg.cfg -o $@ $<

$(BUILD)/macvice-rtc128.prg: $(BUILD)/macvice-rtc128.o src/geos-prg.cfg
	$(LD65) -C src/geos-prg.cfg -o $@ $<

$(BUILD)/macvice-rtc64.grc: src/macvice-rtc64.grc | $(BUILD)
	cp $< $@

$(BUILD)/macvice-rtc128.grc: src/macvice-rtc128.grc | $(BUILD)
	cp $< $@

clean:
	rm -rf $(BUILD)

.PHONY: all clean
