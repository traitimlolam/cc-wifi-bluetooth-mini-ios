TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = WiFiToggleModule
WiFiToggleModule_BUNDLE_EXTENSION = bundle
WiFiToggleModule_FILES = WiFiToggleModule.m
WiFiToggleModule_INSTALL_PATH = /Library/ControlCenter/Bundles
WiFiToggleModule_CFLAGS = -fobjc-arc
WiFiToggleModule_LDFLAGS = -undefined dynamic_lookup
WiFiToggleModule_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/bundle.mk
