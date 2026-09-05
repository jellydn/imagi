# Image Studio — https://just.systems/man/en/

set dotenv-load := false

project := "ImageStudio"
signing := "CODE_SIGNING_ALLOWED=NO"

# Show recipes
default:
    @just --list

# Regenerate ImageStudio.xcodeproj from project.yml (do not edit the xcodeproj)
generate:
    xcodegen generate

# Open the generated Xcode project
open: generate
    open {{project}}.xcodeproj

# StudioCore package tests (no keys, no paid network; Linux-safe)
test:
    swift test

# One StudioCore test (e.g. just test-filter ProviderTests.testOpenAIGenerationUsesNativeSizeAndNumericCount)
test-filter FILTER:
    swift test --filter {{FILTER}}

# macOS SwiftData + ImageStore tests
native-test: generate
    xcodebuild test -project {{project}}.xcodeproj -scheme ImageStudio-NativeTests \
        -destination 'platform=macOS' {{signing}}

# Simulator iPhone app
build-iphone: generate
    xcodebuild -project {{project}}.xcodeproj -scheme ImageStudio-iPhone \
        -destination 'generic/platform=iOS Simulator' {{signing}} build

# Simulator iPad app
build-ipad: generate
    xcodebuild -project {{project}}.xcodeproj -scheme ImageStudio-iPad \
        -destination 'generic/platform=iOS Simulator' {{signing}} build

# Mac app
build-mac: generate
    xcodebuild -project {{project}}.xcodeproj -scheme ImageStudio-Mac \
        -destination 'platform=macOS' {{signing}} build

# All three app targets
build-apps: build-iphone build-ipad build-mac

# Run every prek hook on tracked files
prek:
    prek run --all-files

# Install prek Git shims
prek-install:
    prek install

# Remove SwiftPM and generated Xcode output
clean:
    rm -rf .build/ .swiftpm/ {{project}}.xcodeproj DerivedData/
