# Makefile

.PHONY: project test run

project:
	xcodegen generate

test: project
	xcodebuild test -scheme QuotAI -destination 'platform=macOS' -quiet

run: project
	open QuotAI.xcodeproj
