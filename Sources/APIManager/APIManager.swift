// The Swift Programming Language
// https://docs.swift.org/swift-book
//
//  APIClient.swift
//  Despir
//
//  Created by Prabhjot Singh on 05/01/26.
//
/**
 - Madate -
    * Check both positivive and negative cases for api calling
    * Login - email and password -> response(Temp. token & otp on phone) --- Verify (Params - temp token & OTP) -> Response (Token) -- use this in all Api as Bearer token...
    * UUID will be used to update the user .
 */
import Foundation
import SwiftUI
import SVProgressHUD

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case serverError(Int)
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .decodingError:
            return "Failed to decode response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .custom(let message):
            return message
        }
    }
}

@MainActor
public final class APIManager {

    public static let shared = APIManager()

    private init() {}
  
  //MARK: - API request method

 public func request<T: Decodable>(
    url: URL?,
    methodType: String,
    headers: [String: String] = [:],
    body: Encodable? = nil,
    responseType: T.Type
  ) async throws -> T {
    
    if Indicator.isEnabledIndicator {
      Indicator.sharedInstance.showIndicator()
    }
    
    guard let url = url else {
      throw APIError.invalidURL
    }
    
    // Request
    var request = URLRequest(url: url)
    request.httpMethod = methodType
    
    headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
    
    if let body {
      request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
    // API Call
//    let (data, response) = try await URLSession.shared.data(for: request)
      do {
          let (data, response) = try await URLSession.shared.data(for: request)
          Indicator.sharedInstance.hideIndicator()

          guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
          }
          guard (200...404).contains(httpResponse.statusCode) else {
                 throw APIError.serverError(httpResponse.statusCode)
          }
          
          do {
              let decoded = try JSONDecoder().decode(T.self, from: data)
              return decoded
          } catch let error as DecodingError {
              print("❌ Decoding Error:", error)
              print("📦 Raw JSON:", String(data: data, encoding: .utf8) ?? "nil")
              throw error
          } catch {
              print("❌ Unknown Error:", error)
              throw error
          }


          // Handle success
      } catch {
          Indicator.sharedInstance.hideIndicator()
          throw APIError.custom(error.localizedDescription)

      }
   
  }
  
  //MARK: - API Multipart request methods
  
  public func multipartRequest<T: Decodable>(
    url: URL?,
    methodType: String,
    headers: [String: String] = [:],
    parameters: [String: String] = [:],
    imageData: Data,
    imageKey: String = "image",
    fileName: String = "image.jpg",
    mimeType: String = "image/jpeg",
    responseType: T.Type
  ) async throws -> T {
    
    if Indicator.isEnabledIndicator {
      Indicator.sharedInstance.showIndicator()
    }
    
    guard let url = url else {
      Indicator.sharedInstance.hideIndicator()
      throw APIError.invalidURL
    }
    
    let boundary = UUID().uuidString
    
    var request = URLRequest(url: url)
    request.httpMethod = methodType
    request.setValue("multipart/form-data; boundary=\(boundary)",
                     forHTTPHeaderField: "Content-Type")
    
    headers.forEach {
      request.setValue($0.value, forHTTPHeaderField: $0.key)
    }
    
    request.httpBody = createMultipartBody(
      boundary: boundary,
      parameters: parameters,
      imageData: imageData,
      imageKey: imageKey,
      fileName: fileName,
      mimeType: mimeType
    )
    
    let (data, response) = try await URLSession.shared.data(for: request)
    Indicator.sharedInstance.hideIndicator()
    
    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIError.invalidResponse
    }
    
    guard (200...404).contains(httpResponse.statusCode) else {
           throw APIError.serverError(httpResponse.statusCode)
    }
    
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw APIError.decodingError
    }
  }
  
  private func createMultipartBody(
      boundary: String,
      parameters: [String: String],
      imageData: Data,
      imageKey: String,
      fileName: String,
      mimeType: String
  ) -> Data {

      var body = Data()
      let lineBreak = "\r\n"

      for (key, value) in parameters {
          body.append("--\(boundary)\(lineBreak)")
          body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)")
          body.append("\(value)\(lineBreak)")
      }

      body.append("--\(boundary)\(lineBreak)")
      body.append("Content-Disposition: form-data; name=\"\(imageKey)\"; filename=\"\(fileName)\"\(lineBreak)")
      body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)")
      body.append(imageData)
      body.append(lineBreak)

      body.append("--\(boundary)--\(lineBreak)")
      return body
  }
  
}

struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        self.encodeClosure = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

// MARK: Indicator Class
@MainActor
public class Indicator {
  
  public static let sharedInstance = Indicator()
  
  public static var isEnabledIndicator = true
  
  init() {
    SVProgressHUD.setDefaultMaskType(.black)
    SVProgressHUD.setMinimumDismissTimeInterval(0.3)
  }
  
  func showIndicator(_ message: String? = nil) {
    DispatchQueue.main.async {
      if let message {
        SVProgressHUD.show(withStatus: message)
      } else {
        SVProgressHUD.show()
      }
    }
  }
  
  func hideIndicator() {
    DispatchQueue.main.async {
      SVProgressHUD.dismiss()
    }
  }
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
