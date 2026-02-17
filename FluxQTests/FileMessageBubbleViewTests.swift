import Testing
@testable import FluxQ

@Suite("FileMessageBubbleView Logic Tests")
struct FileMessageBubbleViewTests {

    // MARK: - fileIcon

    @Test("PDF files use doc.fill icon")
    func fileIconPDF() {
        #expect(FileMessageBubbleView.fileIcon(for: "report.pdf") == "doc.fill")
    }

    @Test("Image files use photo.fill icon")
    func fileIconImages() {
        #expect(FileMessageBubbleView.fileIcon(for: "photo.jpg") == "photo.fill")
        #expect(FileMessageBubbleView.fileIcon(for: "image.jpeg") == "photo.fill")
        #expect(FileMessageBubbleView.fileIcon(for: "screenshot.png") == "photo.fill")
        #expect(FileMessageBubbleView.fileIcon(for: "animation.gif") == "photo.fill")
        #expect(FileMessageBubbleView.fileIcon(for: "live.heic") == "photo.fill")
    }

    @Test("Video files use film.fill icon")
    func fileIconVideos() {
        #expect(FileMessageBubbleView.fileIcon(for: "movie.mp4") == "film.fill")
        #expect(FileMessageBubbleView.fileIcon(for: "clip.mov") == "film.fill")
        #expect(FileMessageBubbleView.fileIcon(for: "video.avi") == "film.fill")
    }

    @Test("Archive files use archivebox.fill icon")
    func fileIconArchives() {
        #expect(FileMessageBubbleView.fileIcon(for: "backup.zip") == "archivebox.fill")
        #expect(FileMessageBubbleView.fileIcon(for: "archive.rar") == "archivebox.fill")
        #expect(FileMessageBubbleView.fileIcon(for: "compressed.7z") == "archivebox.fill")
    }

    @Test("Unknown extensions default to doc.fill")
    func fileIconUnknown() {
        #expect(FileMessageBubbleView.fileIcon(for: "readme.txt") == "doc.fill")
        #expect(FileMessageBubbleView.fileIcon(for: "data.csv") == "doc.fill")
        #expect(FileMessageBubbleView.fileIcon(for: "noextension") == "doc.fill")
    }

    @Test("Extension matching is case-insensitive")
    func fileIconCaseInsensitive() {
        #expect(FileMessageBubbleView.fileIcon(for: "PHOTO.JPG") == "photo.fill")
        #expect(FileMessageBubbleView.fileIcon(for: "Video.MP4") == "film.fill")
        #expect(FileMessageBubbleView.fileIcon(for: "Archive.ZIP") == "archivebox.fill")
    }

    // MARK: - formattedFileSize

    @Test("Formats zero bytes")
    func formattedFileSizeZero() {
        let result = FileMessageBubbleView.formattedFileSize(0)
        #expect(result == "Zero KB" || result.contains("0"))
    }

    @Test("Formats kilobytes")
    func formattedFileSizeKB() {
        let result = FileMessageBubbleView.formattedFileSize(1024)
        #expect(result.contains("KB") || result.contains("kB"))
    }

    @Test("Formats megabytes")
    func formattedFileSizeMB() {
        let result = FileMessageBubbleView.formattedFileSize(5_242_880)
        #expect(result.contains("MB"))
    }

    @Test("Formats gigabytes")
    func formattedFileSizeGB() {
        let result = FileMessageBubbleView.formattedFileSize(2_147_483_648)
        #expect(result.contains("GB"))
    }
}
