# Native AppKit, SwiftUI only where bridged

The app is built in Swift on AppKit (`NSStatusItem`, `NSPanel`, `NSTextView`/TextKit), with SwiftUI used only for secondary views such as Settings via `NSHostingView`. Instant summon via hotkey is the core value, and AppKit gives the most reliable control over panel focus, window levels and text-editing performance; the reference app (Stik) uses a different stack, and Tauri/Electron were rejected for footprint and startup latency in an always-running app. Mac-only is accepted.
