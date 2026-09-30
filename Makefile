INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MiOSTweak
MiOSTweak_FILES = $(wildcard MiOSTweak/*.x) $(wildcard MiOSTweak/*.m)
MiOSTweak_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
MiOSTweak_FRAMEWORKS = Foundation CoreFoundation UIKit CoreLocation

APPLICATION_NAME = MiOS
MiOS_FILES = $(wildcard MiOSApp/*.m) $(wildcard MiOSApp/Controllers/*.m) $(wildcard MiOSApp/Views/*.m) $(wildcard MiOSApp/Models/*.m) $(wildcard MiOSApp/Utils/*.m) $(wildcard MiOSApp/UI/*.m)
MiOS_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
MiOS_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore CoreLocation MapKit
MiOS_INSTALL_PATH = /Applications
MiOS_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "killall -9 SpringBoard"
