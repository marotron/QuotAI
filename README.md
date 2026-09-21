# QuotAI

macOS **Swift** menu-bar app for Cursor Spending quota (Cursor Models + Grok Bot).

**Stack:** Swift / SwiftUI `MenuBarExtra`, XcodeGen, macOS 14+  
**Status:** live Connect fetch wired — open app to verify meters  
**License:** [MIT](LICENSE)  
**Wayfinder:** `.scratch/quotai/map.md`  
**Product / tech:** `docs/pr.md`, `docs/tech-specs.md`

## Build

```bash
make project   # xcodegen generate
make test      # QuotAICore unit tests
open QuotAI.xcodeproj
```

Production code lives only under `QuotAI/` and `QuotAICore/` (Swift). The Python script under `.scratch/quotai/poc/` is a **throwaway** API proof, not the app.
