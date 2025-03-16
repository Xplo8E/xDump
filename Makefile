TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = xDump
THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e

THEOS_DEVICE_IP = vinay.local

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = xDump
CODESIGN_ENTITLEMENT = entitlements.plist

xDump_FILES = main.m XXAppDelegate.m XXRootViewController.m XXLogsViewController.m XXDecryptor.m
xDump_FRAMEWORKS = UIKit CoreGraphics
xDump_BUNDLE_RESOURCE_DIRS = Resources
xDump_BUNDLE_RESOURCES = Resources/AppIcon.appiconset
xDump_RESOURCE_FILES = Resources/AppIcon.appiconset Resources/AppIcon.appiconset/Contents.json Resources/AppIcon.png
xDump_CFLAGS = -fobjc-arc
xDump_EXTRA_FRAMEWORKS = AltList
xDump_CODESIGN_FLAGS = -S$(CODESIGN_ENTITLEMENT)
include $(THEOS_MAKE_PATH)/application.mk

# after-install::
# 	install.exec "killall -9 SpringBoard"