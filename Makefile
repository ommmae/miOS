ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

# Build a rootless jailbreak .deb by default. For IPA injection you only need the built
# .dylib (see docs/INJECTION.md) — THEOS_PACKAGE_SCHEME is irrelevant there.
THEOS_PACKAGE_SCHEME ?= rootless

INSTALL_TARGET_PROCESSES = Instagram

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = miOS
miOS_FILES = \
    Tweak/Tweak.x \
    Tweak/MiOSContainer.m \
    Tweak/MiOSDeviceDB.m \
    Tweak/MiOSCrypt.m \
    Tweak/MiOSTheme.m \
    Tweak/MiOSUI.m
miOS_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
miOS_FRAMEWORKS = Foundation CoreFoundation UIKit CoreLocation MapKit \
                  Security CoreTelephony SystemConfiguration CoreMotion \
                  QuartzCore MessageUI
miOS_PRIVATE_FRAMEWORKS =

# Bake the sideloaded-IPA install path into LC_ID_DYLIB so it matches the LC_LOAD_DYLIB
# the patcher inserts into Instagram. Some signers (AltStore / Sideloadly) reject a
# dylib whose own install name does not match the loader path, which was silently
# leaving the dylib unloaded on resign.
miOS_LDFLAGS = -Wl,-install_name,@executable_path/Frameworks/miOS.dylib

include $(THEOS_MAKE_PATH)/tweak.mk
