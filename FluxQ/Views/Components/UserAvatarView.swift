import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct UserAvatarView: View {
    let avatarData: Data?
    let size: CGFloat

    var body: some View {
        Group {
            if let image = makeImage() {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func makeImage() -> Image? {
        guard let avatarData else { return nil }

        #if canImport(UIKit)
        guard let uiImage = UIImage(data: avatarData) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: avatarData) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}
