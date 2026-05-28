## Makefile.am for the native macOS VICE engine bridge.

AM_CPPFLAGS = \
	@VICE_CPPFLAGS@ \
	@ARCH_INCLUDES@ \
	-I$(top_srcdir)/src/arch/headless \
	-I$(top_srcdir)/src/arch/shared \
	-I$(top_srcdir)/src/arch/shared/hotkeys \
	$(extra_includes) \
	-I$(top_builddir)/src \
	-I$(top_srcdir)/src \
	-I$(top_srcdir)/src/crtc \
	-I$(top_srcdir)/src/drive \
	-I$(top_srcdir)/src/joyport \
	-I$(top_srcdir)/src/lib/p64 \
	-I$(top_srcdir)/src/raster \
	-I$(top_srcdir)/src/rs232drv \
	-I$(top_srcdir)/src/sid \
	-I$(top_srcdir)/src/vdc \
	-I$(top_srcdir)/src/c64 \
	-I$(top_srcdir)/src/c64dtv \
	-I$(top_srcdir)/src/c128 \
	-I$(top_srcdir)/src/cbm2 \
	-I$(top_srcdir)/src/pet \
	-I$(top_srcdir)/src/plus4 \
	-I$(top_srcdir)/src/scpu64 \
	-I$(top_srcdir)/src/vic20 \
	-I$(top_srcdir)/src/samplerdrv \
	-I$(top_srcdir)/src/c64/cart \
	-I$(top_srcdir)/src/imagecontents \
	-I$(top_srcdir)/src/monitor \
	-I$(top_srcdir)/src/tapeport \
	-I$(top_srcdir)/src/core/rtc \
	-I$(top_srcdir)/src/hvsc \
	-I$(top_srcdir)/src/datasette

AM_CFLAGS = @VICE_CFLAGS@

AM_CXXFLAGS = @VICE_CXXFLAGS@

AM_OBJCFLAGS = @VICE_OBJCFLAGS@

AM_LDFLAGS = @VICE_LDFLAGS@

noinst_LIBRARIES = libarch.a libtoolarch.a

libarch_a_SOURCES = \
	../headless/archdep.c \
	kbd.c \
	../headless/console.c \
	../headless/uimon.c \
	uistatusbar.c \
	hotkeys.c \
	joystick.c \
	main.c \
	mainexit.c \
	ui.c \
	video.c \
	vicemacbridge.c \
	vsidui.c \
	vsyncarch.c \
	../headless/c64scui.c \
	../headless/mousedrv.c \
	../headless/c64dtvui.c \
	../headless/scpu64ui.c \
	../headless/c128ui.c \
	../headless/vic20ui.c \
	../headless/petui.c \
	../headless/plus4ui.c \
	../headless/cbm2ui.c \
	../headless/cbm5x0ui.c \
	../headless/c64ui.c

libtoolarch_a_SOURCES = \
	../headless/archdep.c

EXTRA_DIST = \
	kbd.h \
	ui.h \
	vicemacbridge.h \
	videoarch.h
