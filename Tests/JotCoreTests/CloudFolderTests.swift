import Foundation
import Testing
@testable import JotCore

/// Recognising Notes Folders that a cloud service syncs, by path.
struct CloudFolderTests {
    let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)

    private func service(_ path: String) -> String? {
        CloudFolder.service(syncing: home.appendingPathComponent(path), home: home)
    }

    @Test func iCloudDrive() {
        #expect(service("Library/Mobile Documents/com~apple~CloudDocs") == "iCloud Drive")
        #expect(service("Library/Mobile Documents/com~apple~CloudDocs/Notes") == "iCloud Drive")
    }

    @Test func anAppsICloudFolder() {
        #expect(service("Library/Mobile Documents/iCloud~md~obsidian/Documents/Vault") == "iCloud Drive")
    }

    @Test func fileProviderServicesAreNamedFromTheirFolder() {
        #expect(service("Library/CloudStorage/Dropbox/Notes") == "Dropbox")
        #expect(service("Library/CloudStorage/GoogleDrive-someone@gmail.com/My Drive/Notes") == "Google Drive")
        #expect(service("Library/CloudStorage/OneDrive-Personal") == "OneDrive")
        #expect(service("Library/CloudStorage/OneDrive-SharedLibraries-Contoso/Docs") == "OneDrive")
        #expect(service("Library/CloudStorage/Box-Box/Notes") == "Box")
        #expect(service("Library/CloudStorage/iCloudDrive-iCloudDrive (24.05.25 17:49)/Notes") == "iCloud Drive")
    }

    @Test func anUnknownFileProviderIsStillRecognised() {
        #expect(service("Library/CloudStorage/SomeSync-account/Notes") == "SomeSync")
    }

    @Test func theFoldersThemselvesCount() {
        #expect(service("Library/CloudStorage/Dropbox") == "Dropbox")
        #expect(service("Library/CloudStorage") == nil)
        #expect(service("Library/Mobile Documents") == nil)
    }

    @Test func localFoldersAreNotCloudFolders() {
        #expect(service("Documents/Jot") == nil)
        #expect(service("Notes/Library/CloudStorage/Dropbox") == nil)
        #expect(CloudFolder.service(syncing: URL(fileURLWithPath: "/Volumes/Data/Notes"), home: home) == nil)
    }
}
