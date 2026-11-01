THEOS_PACKAGE_SCHEME = roothide
ARCHS = arm64e
TARGET = iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HelloMody
HelloMody_FILES = Tweak.xm
HelloMody_CFLAGS = -fobjc-arc -Wall

include $(THEOS_MAKE_PATH)/tweak.mk
