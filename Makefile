TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = SpringBoard Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PleaseKeepLPM
PleaseKeepLPM_FILES = Tweak.x
PleaseKeepLPM_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
