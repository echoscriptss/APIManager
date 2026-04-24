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

extension Notification.Name {
    static let refreshTokenUnauthorized = Notification.Name("RefreshTokenExpired") // for refresh token expire and logout
    static let accessTokenRefreshed = Notification.Name("AccessTokenRefreshed")
}


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
extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
public struct MultipartFile {
    public let data: Data
    public let name: String        // form field name (e.g. "file")
    public let fileName: String
    public let mimeType: String

    public init(
        data: Data,
        name: String,
        fileName: String,
        mimeType: String
    ) {
        self.data = data
        self.name = name
        self.fileName = fileName
        self.mimeType = mimeType
    }
}

public struct refreshTokenModel: Encodable {
    public let refreshToken: String
}

struct refreshResponse: Codable {
    let success: Bool?
    let statusCode: Int?
    let path: String?
    let timestamp: String?
    let message: String?
    let error: String?
    let data: dataToken?
}

struct dataToken: Codable {
    let accessToken: String?
    let refreshToken: String?

}

@MainActor
public final class APIManager {

    public static let shared = APIManager()
    private var authtoken = ""
    private var refreshtoken = ""
    private var refreshURL = ""
    private init() {}
  
  //MARK: - API request method

    /*
     1. header = nil and 401 - non auth api -- do nothing
     2. header != nil and 401 - auth expired -- use refreshtoken and get auth
     */
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
// ---------------------------------------------------------------------------------------
    var request = URLRequest(url: url)
    request.httpMethod = methodType
      if let token = headers["Authorization"] {
          authtoken = token
      }
      if let token = headers["RefreshToken"] {
          refreshtoken = token
      }
      if let url = headers["BaseUrl"] {
          refreshURL = "\(url)/mobile/auth/refresh"
      }
      
      headers.forEach { key, value in
          if key == "Authorization" {
              request.setValue(value, forHTTPHeaderField: key)
          }
          if key == "X-Reset-Token" {
              request.setValue(value, forHTTPHeaderField: key)
          }
      }
// ---------------------------------------------------------------------------------------
      
      
    if let body {
      request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
      do {
          let (data, response) = try await URLSession.shared.data(for: request)
          Indicator.sharedInstance.hideIndicator()

          guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
          }
         
          if headers.count > 0 && httpResponse.statusCode == 401 {
              // make api call for refresh
              let refreshToken = refreshTokenModel(refreshToken: refreshtoken)
              let success = try await handle401(url: URL(string: refreshURL), methodType: "POST", body: refreshToken, responseType: refreshResponse.self)
             
              if success.success ?? false {
                  let headerAuthToken = ["Authorization" : "Bearer \(success.data?.accessToken ?? "")"]
                  return try await self.request(url: url, methodType: methodType, headers: headerAuthToken, body: body, responseType: T.self)
              } else {
                  throw URLError(.userAuthenticationRequired)
              }
          }
          
          guard (200...422).contains(httpResponse.statusCode) else {
                 throw APIError.serverError(httpResponse.statusCode)
              
          }
         // print(String(data: data, encoding: .utf8) ?? "Invalid JSON")

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
    
//    var request = URLRequest(url: url)
      
      var request = URLRequest(url: url)
      request.httpMethod = methodType
        if let token = headers["Authorization"] {
            authtoken = token
        }
        if let token = headers["RefreshToken"] {
            refreshtoken = token
        }
        if let url = headers["BaseUrl"] {
            refreshURL = "\(url)/mobile/auth/refresh"
        }
        
        headers.forEach { key, value in
            if key == "Authorization" {
                request.setValue(value, forHTTPHeaderField: key)
            }
            if key == "X-Reset-Token" {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

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
      if httpResponse.statusCode == 401 {
          
          let refreshToken = refreshTokenModel(refreshToken: refreshtoken)
          let success = try await handle401(url: URL(string: refreshURL), methodType: "POST", body: refreshToken, responseType: refreshResponse.self)
         
          if success.success ?? false {
              let headerAuthToken = ["Authorization" : "Bearer \(success.data?.accessToken ?? "")"]
              return try await self.multipartRequest(url: url, methodType: methodType, imageData: imageData, responseType: responseType)
//              return try await self.request(url: url, methodType: methodType, headers: headerAuthToken, body: body, responseType: T.self)
          } else {
              throw URLError(.userAuthenticationRequired)
          }

      }
    guard (200...422).contains(httpResponse.statusCode) else {
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
    
    // MARK: - Upload Method
    public func uploadDocumentFiles<T: Decodable>(url: URL?,  methodType: String,  headers: [String: String] = [:], parameters: [String: String] = [:], files: [MultipartFile], responseType: T.Type) async throws -> T {

        if Indicator.isEnabledIndicator {
            Indicator.sharedInstance.showIndicator()

        }

        defer {
            Indicator.sharedInstance.hideIndicator()
        }

        guard let url = url else {
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString

//        var request = URLRequest(url: url)
        
        var request = URLRequest(url: url)
        request.httpMethod = methodType
          if let token = headers["Authorization"] {
              authtoken = token
          }
          if let token = headers["RefreshToken"] {
              refreshtoken = token
          }
          if let url = headers["BaseUrl"] {
              refreshURL = "\(url)/mobile/auth/refresh"
          }
          
          headers.forEach { key, value in
              if key == "Authorization" {
                  request.setValue(value, forHTTPHeaderField: key)
              }
              if key == "X-Reset-Token" {
                  request.setValue(value, forHTTPHeaderField: key)
              }
          }

        
        request.httpMethod = methodType
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        headers.forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }

        let body = createMultipartBody(
            boundary: boundary,
            parameters: parameters,
            files: files
        )

        request.httpBody = body
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if httpResponse.statusCode == 401 {
            
            let refreshToken = refreshTokenModel(refreshToken: refreshtoken)
            let success = try await handle401(url: URL(string: refreshURL), methodType: "POST", body: refreshToken, responseType: refreshResponse.self)
           
            if success.success ?? false {
                let headerAuthToken = ["Authorization" : "Bearer \(success.data?.accessToken ?? "")"]
                return try await self.uploadDocumentFiles(url: url, methodType: methodType, files: files, responseType: responseType)
  //              return try await self.request(url: url, methodType: methodType, headers: headerAuthToken, body: body, responseType: T.self)
            } else {
                throw URLError(.userAuthenticationRequired)
            }

        }
        guard (200...422).contains(httpResponse.statusCode) else {
            
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
          return try JSONDecoder().decode(T.self, from: data)
        } catch {
          throw APIError.decodingError
        }
    }

    // MARK: - Multipart Body
    private func createMultipartBody(
        boundary: String,
        parameters: [String: String],
        files: [MultipartFile]
    ) -> Data {

        let lineBreak = "\r\n"
        var body = Data()

        // Parameters
        for (key, value) in parameters {
            body.appendString("--\(boundary)\(lineBreak)")
            body.appendString("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)")
            body.appendString("\(value)\(lineBreak)")
        }

        // Files
        for file in files {
            body.appendString("--\(boundary)\(lineBreak)")
            body.appendString(
                "Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.fileName)\"\(lineBreak)"
            )
            body.appendString("Content-Type: \(file.mimeType)\(lineBreak)\(lineBreak)")
            body.append(file.data)
            body.appendString(lineBreak)
        }

        body.appendString("--\(boundary)--\(lineBreak)")
        return body
    }
    
    // -------------------------------------------------------------------------------------------------------------------------------------
    fileprivate func handle401<T: Decodable>(url: URL?, methodType: String, body: Encodable? = nil, responseType: T.Type) async throws -> T {
        if Indicator.isEnabledIndicator {
          Indicator.sharedInstance.showIndicator()
        }
        
        guard let url = url else {
          throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = methodType
        
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
              /*
               1. header = nil and 401 - non auth api -- do nothing
               2. header != nil and 401 - auth expired -- use refreshtoken and get auth
               
               */
              if httpResponse.statusCode == 401 {
                  NotificationCenter.default.post(name: .refreshTokenUnauthorized, object: nil)
              }
              guard (200...422).contains(httpResponse.statusCode) else {
                     throw APIError.serverError(httpResponse.statusCode)
              }
              do {
                  if let response: refreshResponse = parseResponse(refreshResponse.self, data: data) {
                      NotificationCenter.default.post(
                      name: .accessTokenRefreshed,
                      object: nil,
                      userInfo: ["accessToken": response.data?.accessToken ?? "", "refreshToken" : response.data?.refreshToken ?? ""]
                      )
                  }

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
    
    func parseResponse<T: Decodable>(_ type: T.Type, data: Data) -> T? {
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    // -------------------------------------------------------------------------------------------------------------------------------------

    
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
