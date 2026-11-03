# Makefile

.PHONY: project test run preview dmg release

project:
	xcodegen generate

test: project
	xcodebuild test -scheme QuotAI -destination 'platform=macOS' -quiet

run: project
	open QuotAI.xcodeproj

# Kill → rebuild → relaunch the panel design-preview app in one step.
preview: project
	@xcodebuild -scheme QuotAIPanelPreview -configuration Debug -destination 'platform=macOS' build -quiet
	@pkill -x QuotAIPanelPreview 2>/dev/null || true
	@open ~/Library/Developer/Xcode/DerivedData/QuotAI-*/Build/Products/Debug/QuotAIPanelPreview.app

dmg: project
	@./Scripts/release/dmg.sh

release: test dmg
