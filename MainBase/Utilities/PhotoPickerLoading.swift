import PhotosUI
import SwiftUI
import UIKit

/// Loads picked `PhotosPickerItem`s as `UIImage`s, silently skipping any that fail to decode.
func loadImages(from items: [PhotosPickerItem]) async -> [UIImage] {
    var images: [UIImage] = []
    for item in items {
        if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
            images.append(image)
        }
    }
    return images
}
