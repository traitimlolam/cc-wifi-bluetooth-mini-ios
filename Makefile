TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CCWiFiBTHelper
CCWiFiBTHelper_FILES = Tweak.x
CCWiFiBTHelper_CFLAGS = -fobjc-arc
CCWiFiBTHelper_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += WiFiToggleModule BluetoothToggleModule
include $(THEOS_MAKE_PATH)/aggregate.mk
