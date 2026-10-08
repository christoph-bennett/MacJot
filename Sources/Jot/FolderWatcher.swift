import CoreServices
import Foundation

/// Watches the Notes Folder with FSEvents and calls `onChange` on the main
/// queue, at most a few times a second, when anything in it changes: Notes
/// added, edited, renamed or deleted by other apps, sync, or Finder's Put Back.
/// Jot's own writes are reported too; the Notes Folder tells them apart.
@MainActor
final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void

    init(_ folder: URL, onChange: @escaping () -> Void) {
        self.onChange = onChange
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.onChange() }  // the stream is scheduled on the main queue
        }
        guard let stream = FSEventStreamCreate(
            nil, callback, &context, [folder.path] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            // Seconds. Events are collected this long after the first one before they're
            // reported, so a save that removes the file and writes it again is
            // normally seen as a whole, not halfway as a deletion.
            0.2,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)
        ) else {
            NSLog("Jot: couldn't watch the Notes Folder")
            return
        }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    isolated deinit {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }
}
