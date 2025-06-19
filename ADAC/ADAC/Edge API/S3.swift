// Licensed under the Any Distance Source-Available License
//
//  S3.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/13/23.
//

import UIKit
import SwiftyJSON

class S3 {
    static func uploadImage(_ image: UIImage, resizeToWidth: CGFloat = 1000.0) async throws -> URL {
        let resizedImage: UIImage = {
            if image.size.width <= resizeToWidth {
                return image
            }
            return image.resized(withNewWidth: resizeToWidth, imageScale: 1.0)
        }()
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.9) else {
            throw S3Error.cantEncodeImage
        }

        let url = Edge.host
            .appendingPathComponent("media")
            .appendingPathComponent("upload")
        let fileName = UUID().uuidString + ".jpg"
        let filePath = ADUser.current.id + "/" + fileName
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "path", value: filePath)
        ]
        guard let urlWithComponents = components?.url else {
            throw S3Error.urlEncodingError
        }

        var request = try Edge.defaultRequest(with: urlWithComponents, method: .post)
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        print(urlWithComponents)

        // Generate multipart form data
        var formData = Data()
        formData.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"media\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        formData.append(imageData)
        formData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, response) = try await URLSession.shared.upload(for: request, from: formData)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            print(stringData)
            throw S3Error.requestError(stringData)
        }

        let json = try JSON(data: data)
        let mediaJSON = try json["media"].rawData()
        let responsePayload = try JSONDecoder().decode(S3UploadResponsePayload.self, from: mediaJSON)
        if let url = URL(string: responsePayload.assetURL) {
            return url
        } else {
            throw S3Error.uploadedURLDecodingError
        }
    }

    static func deleteMedia(withURL mediaUrl: URL) async throws {
        guard !mediaUrl.isRandomCoverPhotoURL else {
            return
        }
        
        let url = Edge.host
            .appendingPathComponent("media")
            .appendingPathComponent("delete")

        let fullMediaUploadsHost: String = "https://" + Edge.mediaUploadsHost + "/"
        let filePath = mediaUrl.absoluteString.replacingOccurrences(of: fullMediaUploadsHost, with: "")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "path", value: filePath)
        ]
        guard let urlWithComponents = components?.url else {
            throw S3Error.urlEncodingError
        }

        let request = try Edge.defaultRequest(with: urlWithComponents, method: .delete)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            print(stringData)
            throw S3Error.requestError(stringData)
        }
    }

    static func randomCoverPhotoURL() -> URL {
        let int = Int.random(in: 1...10)
        let urlString = Edge.coverPhotoURLPrefix + (int == 10 ? "" : "0") + String(int) + ".png"
        return URL(string: urlString)!
    }
}

extension URL {
    var isRandomCoverPhotoURL: Bool {
        return absoluteString.contains(Edge.coverPhotoURLPrefix)
    }
}

struct S3UploadResponsePayload: Codable {
    var assetURL: String
    var userID: String
    var id: String
}

enum S3Error: Error {
    case cantEncodeImage
    case urlEncodingError
    case requestError(_ errorString: String?)
    case uploadedURLDecodingError
}
