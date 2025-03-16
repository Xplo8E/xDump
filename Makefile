TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = xDump
THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e

PACKAGE_FORMAT = ipa

THEOS_DEVICE_IP = vinay.local

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = xDump
CODESIGN_ENTITLEMENT = entitlements.plist

xDump_FILES = main.m XXAppDelegate.m XXRootViewController.m XXLogsViewController.m XXDecryptor.m
xDump_FRAMEWORKS = UIKit CoreGraphics
xDump_BUNDLE_RESOURCE_DIRS = Resources
xDump_CFLAGS = -fobjc-arc
xDump_EXTRA_FRAMEWORKS = AltList
xDump_CODESIGN_FLAGS = -S$(CODESIGN_ENTITLEMENT)
include $(THEOS_MAKE_PATH)/application.mk

after-install::
	rm -rf Payload
	mkdir -p $(THEOS_STAGING_DIR)/Payload
	ldid -Sentitlements.plist $(THEOS_STAGING_DIR)/Applications/xDump.app/xDump
	cp -a $(THEOS_STAGING_DIR)/Applications/* $(THEOS_STAGING_DIR)/Payload
	mv $(THEOS_STAGING_DIR)/Payload .
	zip -q -r xDump.ipa Payload