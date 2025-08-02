import Foundation
import UIKit

final class Downloader {
    enum DownloadError: Error {
        case invalidURL
        case networkError(Error)
        case invalidData
        case cancelled
    }
    
    private var cancellationToken: Task<Void, Never>?
    private let imageCache = NSCache<NSString, UIImage>()
    
    func downloadImage(from urlString: String, maxRetries: Int = 3) async throws -> UIImage {
        if let cachedImage = imageCache.object(forKey: urlString as NSString) {
            return cachedImage
        }
        
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL
        }
        
        var attempts = 0
        var lastError: Error?
        
        while attempts < maxRetries {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                if let cancellationToken = cancellationToken, cancellationToken.isCancelled {
                    throw DownloadError.cancelled
                }
                
                guard let image = UIImage(data: data) else {
                    throw DownloadError.invalidData
                }
                
                // Cache the downloaded image
                imageCache.setObject(image, forKey: urlString as NSString)
                return image
            } catch {
                if let cancellationToken = cancellationToken, cancellationToken.isCancelled {
                    throw DownloadError.cancelled
                }
                
                lastError = error
                attempts += 1
                
                if attempts < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempts))) * 1_000_000_000)
                }
            }
        }
        
        throw DownloadError.networkError(lastError ?? NSError(domain: "Unknown", code: 0))
    }
    
    func cancelDownload() {
        cancellationToken?.cancel()
        cancellationToken = Task { }
    }
}
