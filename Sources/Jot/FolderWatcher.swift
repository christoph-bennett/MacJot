import CoreServices
import Foundation

/// Watches the Notes Folder with FSEvents and calls `onChange` on the main
/// queue, at most a few times a second, when anything in it changes: Notes
/// added, edited, renamed or deleted by other apps, sync, or Finder's Put Back.
/// MacJot's own writes are reported too; the Notes Folder tells them apart.
/// `onRootChange` instead when the folder itself was renamed, moved or deleted.
@MainActor
final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void
    private let onRootChange: () -> Void

    init(_ folder: URL, onChange: @escaping () -> Void, onRootChange: @escaping () -> Void) {
        self.onChange = onChange
        self.onRootChange = onRootChange
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, _, flags, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            let rootChanged = (0..<count).contains {
                flags[$0] & FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged) != 0
            }
            MainActor.assumeIsolated {  // the stream is scheduled on the main queue
                if rootChanged { watcher.onRootChange() } else { watcher.onChange() }
            }
        }
        guard let stream = FSEventStreamCreate(
            nil, callback, &context, [folder.path] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            // Seconds. Events are collected this long after the first one before they're
            // reported, so a save that removes the file and writes it again is
            // normally seen as a whole, not halfway as a deletion.
            0.2,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagWatchRoot)
        ) else {
            NSLog("MacJot: couldn't watch the Notes Folder")
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

/// Watches one file (an Outside File, ticket 31) and calls `onChange` on the main
/// queue when it's written, replaced (an atomic save), renamed or deleted. Only
/// the file and its own folder's entries: FSEvents would report everything below
/// the folder, which for a file in the home folder never stops.
@MainActor
final class FileWatcher {
    private let file: URL
    private let onChange: () -> Void
    private var folderSource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?

    init(_ file: URL, onChange: @escaping () -> Void) {
        self.file = file
        self.onChange = onChange
        // The folder's entries change when a save replaces the file, or it's deleted or renamed.
        folderSource = Self.source(for: file.deletingLastPathComponent(), events: .write) { [weak self] in
            self?.changed()
        }
        watchFile()
    }

    isolated deinit {
        folderSource?.cancel()
        fileSource?.cancel()
    }

    private func changed() {
        watchFile()  // a replaced file is a new one to watch
        onChange()
    }

    /// Edits in place change the file, not its folder.
    private func watchFile() {
        fileSource?.cancel()
        fileSource = Self.source(for: file, events: [.write, .extend, .delete, .rename]) { [weak self] in
            self?.changed()
        }
    }

    private static func source(for url: URL, events: DispatchSource.FileSystemEvent,
                               handler: @escaping @MainActor () -> Void) -> DispatchSourceFileSystemObject? {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: events, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { handler() } }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        return source
    }
}
