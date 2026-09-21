# Makefile

.PHONY: project test run dmg release

project:
	xcodegen generate

test: project
	xcodebuild test -scheme QuotAI -destination 'platform=macOS' -quiet

run: project
	open QuotAI.xcodeproj

dmg: project
	@./Scripts/release/dmg.sh

release: test dmg
