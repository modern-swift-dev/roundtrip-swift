SHELL := /bin/bash

SCHEME ?= RoundTrip-Package
IOS_DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro,OS=latest
TVOS_DESTINATION ?= platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest
WATCHOS_DESTINATION ?= platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest
VISIONOS_DESTINATION ?= platform=visionOS Simulator,name=Apple Vision Pro,OS=latest

.PHONY: setup format-check format lint tests documentation documentation-static static-docs site site-setup site-preview internal-link examples \
	apple macos ios tvos watchos visionos

setup:
	brew bundle install
	mint bootstrap
	lefthook install

format-check:
	mint run --no-install nicklockwood/SwiftFormat . --config .swiftformat --lint --quiet

format:
	mint run --no-install nicklockwood/SwiftFormat . --config .swiftformat --quiet
	mint run --no-install realm/SwiftLint --config .swiftlint.yml --fix --quiet

lint:
	mint run --no-install realm/SwiftLint --config .swiftlint.yml --quiet

tests:
	set -o pipefail && swift test | mint run --no-install cpisciotta/xcbeautify -q

documentation:
	bash Scripts/build-documentation.sh

documentation-static:
	bash Scripts/build-static-documentation.sh

static-docs: documentation-static

site-setup:
	npm ci --prefix Website

site:
	bash Scripts/build-site.sh

site-preview:
	node Scripts/preview-site.mjs docs

internal-link:
	node Website/scripts/check-internal-links.mjs docs

examples:
	set -o pipefail && swift test --package-path Examples | mint run --no-install cpisciotta/xcbeautify -q

macos:
	set -o pipefail && xcodebuild test -scheme "$(SCHEME)" -destination 'platform=macOS' | mint run --no-install cpisciotta/xcbeautify -q

ios:
	set -o pipefail && xcodebuild test -scheme "$(SCHEME)" -destination "$(IOS_DESTINATION)" | mint run --no-install cpisciotta/xcbeautify -q

tvos:
	set -o pipefail && xcodebuild test -scheme "$(SCHEME)" -destination "$(TVOS_DESTINATION)" | mint run --no-install cpisciotta/xcbeautify -q

watchos:
	set -o pipefail && xcodebuild test -scheme "$(SCHEME)" -destination "$(WATCHOS_DESTINATION)" | mint run --no-install cpisciotta/xcbeautify -q

visionos:
	set -o pipefail && xcodebuild test -scheme "$(SCHEME)" -destination "$(VISIONOS_DESTINATION)" | mint run --no-install cpisciotta/xcbeautify -q

apple: macos ios tvos watchos visionos
