TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BluetoothToggleModule
BluetoothToggleModule_BUNDLE_EXTENSION = bundle
BluetoothToggleModule_FILES = BluetoothToggleModule.m
BluetoothToggleModule_INSTALL_PATH = /Library/ControlCenter/Bundles
BluetoothToggleModule_CFLAGS = -fobjc-arc
BluetoothToggleModule_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/bundle.mk
