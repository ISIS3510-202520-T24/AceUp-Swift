//
//  ImageCacheService.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 2/12/25.
//

import Foundation
import SwiftUI

@MainActor
class ImageCacheService: ObservableObject {
    static let shared = ImageCacheService()
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Setup cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("EventImages")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure NSCache
        cache.countLimit = 100 // Maximum 100 images in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }
    
    // MARK: - Public Methods
    
    func getImage(url: String) async -> UIImage? {
        let key = NSString(string: url)
        
        // Check memory cache first
        if let cachedImage = cache.object(forKey: key) {
            print("📸 Image loaded from memory cache: \(url)")
            return cachedImage
        }
        
        // Check disk cache
        if let diskImage = loadFromDisk(url: url) {
            print("💾 Image loaded from disk cache: \(url)")
            cache.setObject(diskImage, forKey: key)
            return diskImage
        }
        
        // Download image
        guard let downloadedImage = await downloadImage(url: url) else {
            print("❌ Failed to download image: \(url)")
            return nil
        }
        
        // Save to caches
        cache.setObject(downloadedImage, forKey: key)
        saveToDisk(image: downloadedImage, url: url)
        
        print("✅ Image downloaded and cached: \(url)")
        return downloadedImage
    }
    
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        print("🗑️ Image cache cleared")
    }
    
    // MARK: - Private Methods
    
    private func downloadImage(url: String) async -> UIImage? {
        guard let imageURL = URL(string: url) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            return UIImage(data: data)
        } catch {
            print("❌ Error downloading image: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func loadFromDisk(url: String) -> UIImage? {
        let filename = url.toMD5()
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    private func saveToDisk(image: UIImage, url: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let filename = url.toMD5()
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        try? data.write(to: fileURL)
    }
}

// MARK: - Cached Image View

struct CachedAsyncImage: View {
    let url: String?
    let placeholder: AnyView
    
    @StateObject private var imageLoader = ImageLoader()
    
    init(url: String?, @ViewBuilder placeholder: () -> some View) {
        self.url = url
        self.placeholder = AnyView(placeholder())
    }
    
    var body: some View {
        Group {
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .task {
            if let url = url {
                await imageLoader.loadImage(url: url)
            }
        }
    }
}

@MainActor
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    
    func loadImage(url: String) async {
        self.image = await ImageCacheService.shared.getImage(url: url)
    }
}

// MARK: - String Extension for MD5

extension String {
    func toMD5() -> String {
        // Simple hash for filename - in production you'd use CryptoKit
        return String(self.hashValue)
    }
}
