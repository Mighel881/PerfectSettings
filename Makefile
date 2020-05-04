THEOS_DEVICE_IP = iphone
ARCHS = arm64 arm64e
TARGET = iphone:clang:11.2:11.2

INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PerfectSettings13
PerfectSettings13_FILES = PreferenceOrganizer2.xm PerfectSettings13.xm
PerfectSettings13_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
PerfectSettings13_EXTRA_FRAMEWORKS += Cephei
PerfectSettings13_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk