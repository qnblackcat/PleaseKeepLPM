TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PleaseKeepLPM
PleaseKeepLPM_FILES = Tweak.x
PleaseKeepLPM_CFLAGS = -fobjc-arc

ifeq ($(PLEASEKEEPLPM_DEBUG),1)
PleaseKeepLPM_CFLAGS += -DPLK_DEBUG=1
endif

include $(THEOS_MAKE_PATH)/tweak.mk
