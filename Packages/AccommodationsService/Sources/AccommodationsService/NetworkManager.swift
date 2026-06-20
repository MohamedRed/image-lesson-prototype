import Foundation
import Combine
import FirebaseAuth

public final class NetworkManager {
    private let baseURL: String
    private let session = URLSession.shared
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    public init(baseURL: String) {
        self.baseURL = baseURL
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        
        // Configure date formatting
        let dateFormatter = ISO8601DateFormatter()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }
        
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let dateString = dateFormatter.string(from: date)
            var container = encoder.singleValueContainer()
            try container.encode(dateString)
        }
    }
    
    public func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = false
    ) -> AnyPublisher<T, Error> {
        
        guard let url = buildURL(endpoint: endpoint, queryItems: queryItems) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("LiiveApp/1.0", forHTTPHeaderField: "User-Agent")
        
        // Add authentication if required
        if requiresAuth {
            return addAuthHeaders(to: request)
                .flatMap { [weak self] authenticatedRequest in
                    self?.performRequest(authenticatedRequest, body: body) ?? Empty().eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        } else {
            return performRequest(request, body: body)
        }
    }

    // Convenience for endpoints that return no JSON body
    public func requestVoid(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = false
    ) -> AnyPublisher<Void, Error> {
        return (request(
            endpoint: endpoint,
            method: method,
            body: body,
            queryItems: queryItems,
            requiresAuth: requiresAuth
        ) as AnyPublisher<EmptyResponse, Error>)
        .map { _ in () }
        .eraseToAnyPublisher()
    }
    
    private func buildURL(endpoint: String, queryItems: [URLQueryItem]?) -> URL? {
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")
        components?.queryItems = queryItems
        return components?.url
    }
    
    private func addAuthHeaders(to request: URLRequest) -> AnyPublisher<URLRequest, Error> {
        guard let currentUser = Auth.auth().currentUser else {
            return Fail(error: NetworkError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        return Future { promise in
            currentUser.getIDToken { token, error in
                if let error = error {
                    promise(.failure(error))
                } else if let token = token {
                    var authenticatedRequest = request
                    authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    promise(.success(authenticatedRequest))
                } else {
                    promise(.failure(NetworkError.authTokenMissing))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        body: Encodable?
    ) -> AnyPublisher<T, Error> {
        var finalRequest = request
        
        // Encode request body if provided
        if let body = body {
            do {
                finalRequest.httpBody = try encoder.encode(AnyEncodable(body))
            } catch {
                return Fail(error: error)
                    .eraseToAnyPublisher()
            }
        }
        
        return session.dataTaskPublisher(for: finalRequest)
            .tryMap { [weak self] data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                // Handle different status codes
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw NetworkError.notAuthenticated
                case 403:
                    throw NetworkError.forbidden
                case 404:
                    throw NetworkError.notFound
                case 429:
                    throw NetworkError.rateLimited
                case 500...599:
                    throw NetworkError.serverError
                default:
                    if let errorData = self?.tryDecodeErrorResponse(data) {
                        throw NetworkError.apiError(errorData.message)
                    } else {
                        throw NetworkError.httpError(httpResponse.statusCode)
                    }
                }
            }
            .tryMap { data -> Data in
                // Allow empty bodies for EmptyResponse decoding
                if data.isEmpty, T.self == EmptyResponse.self {
                    return Data("{}".utf8)
                }
                return data
            }
            .decode(type: T.self, decoder: decoder)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    private func tryDecodeErrorResponse(_ data: Data) -> ErrorResponse? {
        try? decoder.decode(ErrorResponse.self, from: data)
    }
}

// MARK: - Supporting Types

public enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

public enum NetworkError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case authTokenMissing
    case forbidden
    case notFound
    case rateLimited
    case serverError
    case invalidResponse
    case apiError(String)
    case httpError(Int)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .notAuthenticated:
            return "Authentication required"
        case .authTokenMissing:
            return "Authentication token missing"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .serverError:
            return "Server error. Please try again later."
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return message
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}

struct ErrorResponse: Codable {
    let error: String
    let message: String
}

struct AnyEncodable: Encodable {
    private let encodable: Encodable
    
    init(_ encodable: Encodable) {
        self.encodable = encodable
    }
    
    func encode(to encoder: Encoder) throws {
        try encodable.encode(to: encoder)
    }
}

// Represents an empty JSON object response {}
public struct EmptyResponse: Decodable {}