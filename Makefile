ARCHS = arm64
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KeepAwake

KeepAwake_FILES = KeepAwake.xm
KeepAwake_FRAMEWORKS = UIKit
KeepAwake_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
