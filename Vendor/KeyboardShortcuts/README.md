# KeyboardShortcuts (vendored)

[sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 3.1.0 (MIT, see `license`), used for MacJot's hotkeys (ADR 0005).

Vendored instead of fetched, because 3.x uses SwiftUI macros whose plugins ship only with Xcode, and MacJot builds with the Command Line Tools. The changes, each marked "MacJot patch":

- `ConflictPolicy.swift` declares its environment value with a plain `EnvironmentKey` instead of `@Entry`.
- `Recorder.swift` has no `#Preview`s.
- `ViewModifiers.swift` stores two `State` values without the `@State` attribute, which is a macro in the macOS 27 SDK.
- `RecorderCocoa.swift` drops the `layout()` override that centres the text across the cancel button: it cut off long shortcuts and looked off-centre.

The test target and the DocC catalogue are left out.

To update: copy `Sources/KeyboardShortcuts` from the new release (without `KeyboardShortcuts.docc`), compare `Package.swift`, and re-apply the patches (`grep -rnE "#Preview|@Entry|@State"` finds what needs them; the `layout()` override has to be removed by hand).
