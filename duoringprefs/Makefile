ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME ?= roothide

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = DuoRingPrefs
DuoRingPrefs_FILES = DuoRootListController.m
DuoRingPrefs_FRAMEWORKS = UIKit CoreFoundation QuartzCore
DuoRingPrefs_PRIVATE_FRAMEWORKS = Preferences
DuoRingPrefs_INSTALL_PATH = /Library/PreferenceBundles
DuoRingPrefs_CFLAGS = -fobjc-arc -Wall -Wextra

include $(THEOS_MAKE_PATH)/bundle.mk
