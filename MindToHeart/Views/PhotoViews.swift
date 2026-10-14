import PhotosUI
import SwiftUI
import UIKit

/// 一张待显示的照片：新建时还没存进数据库，所以和 ThoughtPhoto 分开
struct PhotoItem: Identifiable {
    let id: AnyHashable
    let data: Data
}

/// 图片压缩和缩略图
enum PhotoProcessing {
    /// 长边超过这个尺寸就缩小，够看又不占太多空间
    static let maxDimension: CGFloat = 2048

    static func jpeg(fromImageData data: Data) -> Data? {
        UIImage(data: data).flatMap(jpeg(from:))
    }

    static func jpeg(from image: UIImage) -> Data? {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height, 1))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        // 重新绘制一遍，顺便把照片方向摆正
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    static func thumbnail(from data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: image)
    }
}

/// 添加照片按钮：拍照或从图库选（最多一次 9 张），处理好后回调压缩过的 JPEG
struct PhotoAddButton: View {
    var onAdd: ([Data]) -> Void

    @State private var showingLibrary = false
    @State private var showingCamera = false
    @State private var selection: [PhotosPickerItem] = []

    var body: some View {
        Menu {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("拍照", systemImage: "camera") { showingCamera = true }
            }
            Button("从图库选择", systemImage: "photo.on.rectangle") { showingLibrary = true }
        } label: {
            Label("添加照片", systemImage: "camera")
                .labelStyle(.iconOnly)
                .font(.title3)
        }
        .photosPicker(isPresented: $showingLibrary, selection: $selection, maxSelectionCount: 9, matching: .images)
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            selection = []
            Task {
                var result: [Data] = []
                for item in items {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                    if let jpeg = await Task.detached(operation: { PhotoProcessing.jpeg(fromImageData: data) }).value {
                        result.append(jpeg)
                    }
                }
                onAdd(result)
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                Task {
                    if let jpeg = await Task.detached(operation: { PhotoProcessing.jpeg(from: image) }).value {
                        onAdd([jpeg])
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
}

/// 横向一排缩略图，点开看大图，长按删除
struct PhotoStrip: View {
    let photos: [PhotoItem]
    var onDelete: (AnyHashable) -> Void

    @State private var viewing: PhotoItem?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photos) { photo in
                    Button {
                        viewing = photo
                    } label: {
                        PhotoThumbnail(data: photo.data)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("删除照片", systemImage: "trash", role: .destructive) {
                            onDelete(photo.id)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .fullScreenCover(item: $viewing) { photo in
            PhotoViewer(photos: photos, selection: photo.id)
        }
    }
}

struct PhotoThumbnail: View {
    let data: Data
    var size: CGFloat = 80

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(.secondarySystemFill)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task {
            let data = data
            let maxPixel = size * 3
            image = await Task.detached { PhotoProcessing.thumbnail(from: data, maxPixel: maxPixel) }.value
        }
    }
}

/// 全屏看大图，左右滑动切换
private struct PhotoViewer: View {
    let photos: [PhotoItem]
    @State var selection: AnyHashable
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView(selection: $selection) {
            ForEach(photos) { photo in
                FullImage(data: photo.data)
                    .tag(photo.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
        }
    }

    private struct FullImage: View {
        let data: Data
        @State private var image: UIImage?

        var body: some View {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                let data = data
                image = await Task.detached { PhotoProcessing.thumbnail(from: data, maxPixel: PhotoProcessing.maxDimension) }.value
            }
        }
    }
}

/// 系统相机
private struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
