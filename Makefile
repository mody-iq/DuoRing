ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME ?= roothide
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DuoRing
DuoRing_FILES = Sources/Tweak.xm Sources/DuoGlyphView.m
DuoRing_CFLAGS = -fobjc-arc -Wall -Wextra
DuoRing_FRAMEWORKS = UIKit QuartzCore CoreFoundation

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += duoringprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
