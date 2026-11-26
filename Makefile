.PHONY: build run app dmg test web-install web-dev web-build

CLT_DIR := /Library/Developer/CommandLineTools
CLT_FRAMEWORKS := $(CLT_DIR)/Library/Developer/Frameworks
CLT_LIB := $(CLT_DIR)/Library/Developer/usr/lib

USE_XCODE := $(shell [ -d "/Applications/Xcode.app" ] && defaults read /Library/Preferences/com.apple.dt.Xcode IDEXcodeVersionForAgreedToGMLicense >/dev/null 2>&1 && echo 1 || echo 0)
SWIFT := $(if $(filter 1,$(USE_XCODE)),swift,DEVELOPER_DIR=$(CLT_DIR) swift)

# Release metadata injected into the packaged app's Info.plist (SemVer).
# Example: make dmg VERSION=1.2.0 BUILD_NUMBER=7
VERSION ?= 1.1.0
BUILD_NUMBER ?= 2
APP_CONFIG ?= release
APP_NAME := My Better Life
APP_DIR := .build/$(APP_NAME).app
DMG_PATH := .build/MyBetterLife-v$(VERSION)-macOS.dmg
DMG_STAGING := .build/dmg-staging

# --- Swift Multiplatform App ---

build:
	@if [ "$(USE_XCODE)" = "1" ]; then \
		swift build; \
	else \
		DEVELOPER_DIR=$(CLT_DIR) swift build; \
	fi

run:
	@if [ "$(USE_XCODE)" = "1" ]; then \
		swift run MyBetterLifeMacApp; \
	else \
		DEVELOPER_DIR=$(CLT_DIR) swift run MyBetterLifeMacApp; \
	fi

app:
	@set -e; \
	$(SWIFT) build -c $(APP_CONFIG) --product MyBetterLifeMacApp; \
	BIN_DIR=$$($(SWIFT) build -c $(APP_CONFIG) --show-bin-path); \
	rm -rf "$(APP_DIR)"; \
	mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"; \
	cp "$$BIN_DIR/MyBetterLifeMacApp" "$(APP_DIR)/Contents/MacOS/MyBetterLifeMacApp"; \
	if [ -d "$$BIN_DIR/MyBetterLife_MyBetterLifeMacApp.bundle" ]; then \
		cp -R "$$BIN_DIR/MyBetterLife_MyBetterLifeMacApp.bundle" "$(APP_DIR)/Contents/Resources/"; \
	fi; \
	cp "App/AppIcon.icns" "$(APP_DIR)/Contents/Resources/AppIcon.icns"; \
	printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>CFBundleDevelopmentRegion</key><string>pt-BR</string>\n\t<key>CFBundleDisplayName</key><string>My Better Life</string>\n\t<key>CFBundleExecutable</key><string>MyBetterLifeMacApp</string>\n\t<key>CFBundleIconFile</key><string>AppIcon</string>\n\t<key>CFBundleIdentifier</key><string>com.igordonatti.mybetterlife</string>\n\t<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>\n\t<key>CFBundleName</key><string>My Better Life</string>\n\t<key>CFBundlePackageType</key><string>APPL</string>\n\t<key>CFBundleShortVersionString</key><string>%s</string>\n\t<key>CFBundleVersion</key><string>%s</string>\n\t<key>LSMinimumSystemVersion</key><string>15.0</string>\n\t<key>NSHighResolutionCapable</key><true/>\n</dict>\n</plist>\n' "$(VERSION)" "$(BUILD_NUMBER)" > "$(APP_DIR)/Contents/Info.plist"; \
	plutil -lint "$(APP_DIR)/Contents/Info.plist" >/dev/null; \
	echo "App v$(VERSION) ($(BUILD_NUMBER)) empacotado em: $(APP_DIR) (use 'open \"$(APP_DIR)\"' ou arraste para /Applications)"

# Ad-hoc signed DMG with an /Applications shortcut, ready to attach to a GitHub Release.
dmg: app
	@set -e; \
	codesign --force --deep --sign - "$(APP_DIR)"; \
	codesign --verify --deep --strict "$(APP_DIR)"; \
	rm -rf "$(DMG_STAGING)" "$(DMG_PATH)"; \
	mkdir -p "$(DMG_STAGING)"; \
	cp -R "$(APP_DIR)" "$(DMG_STAGING)/"; \
	ln -s /Applications "$(DMG_STAGING)/Applications"; \
	hdiutil create -volname "$(APP_NAME) $(VERSION)" -srcfolder "$(DMG_STAGING)" -ov -format UDZO "$(DMG_PATH)" >/dev/null; \
	rm -rf "$(DMG_STAGING)"; \
	echo "DMG criado em: $(DMG_PATH)"

test:
	@if [ "$(USE_XCODE)" = "1" ]; then \
		swift test; \
	else \
		DEVELOPER_DIR=$(CLT_DIR) swift test --disable-xctest --enable-swift-testing \
			-Xswiftc -F -Xswiftc $(CLT_FRAMEWORKS) \
			-Xlinker -F -Xlinker $(CLT_FRAMEWORKS) \
			-Xlinker -rpath -Xlinker $(CLT_FRAMEWORKS) \
			-Xlinker -rpath -Xlinker $(CLT_LIB); \
	fi

# --- Web (Landing Page + Documentation Portal) ---

web-install:
	cd web && npm install

web-dev:
	cd web && npm run dev

web-build:
	cd web && npm run build
