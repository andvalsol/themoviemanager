//
//  TMDBClient.swift
//  TheMovieManager
//
//  Created by Owen LaRosa on 8/13/18.
//  Copyright © 2018 Udacity. All rights reserved.
//

import Foundation

class TMDBClient {
    
    static let apiKey = "29a74b4e73ed8148f22b37324cf59aab"
    
    struct Auth {
        static var accountId = 0
        static var requestToken = ""
        static var sessionId = ""
    }
    
    enum Endpoints {
        static let base = "https://api.themoviedb.org/3"
        static let apiKeyParam = "?api_key=\(TMDBClient.apiKey)"
        
        case getWatchlist
        case getRequestToken
        case login
        case createSession
        case webAuth
        case logOut
        case getFavorites
        case search(String)
        case markWatchlist
        case markFavorite
        case posterImage(String)
        
        var stringValue: String {
            switch self {
            case .getRequestToken: return "\(Endpoints.base)/authentication/token/new\(Endpoints.apiKeyParam)"
            case .getWatchlist: return Endpoints.base + "/account/\(Auth.accountId)/watchlist/movies" + Endpoints.apiKeyParam + "&session_id=\(Auth.sessionId)"
            case .login: return "\(Endpoints.base)/authentication/token/validate_with_login\(Endpoints.apiKeyParam)"
            case .createSession: return "\(Endpoints.base)/authentication/session/new\(Endpoints.apiKeyParam)"
            case .webAuth: return "https://www.themoviedb.org/authenticate/\(Auth.requestToken)?redirect_to=themoviemanager:authenticate"
            case .logOut: return "\(Endpoints.base)/authentication/session\(Endpoints.apiKeyParam)"
            case .getFavorites: return "\(Endpoints.base)/account/\(Auth.accountId)/favorite/movies\(Endpoints.apiKeyParam)&session_id=\(Auth.sessionId)"
            case .search (let query): return "\(Endpoints.base)/search/movie/\(Endpoints.apiKeyParam)&query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            case .markWatchlist: return "\(Endpoints.base)/account/\(Auth.accountId)/watchlist/\(Endpoints.apiKeyParam)"
            case .markFavorite: return "\(Endpoints.base)/account/\(Auth.accountId)/favorite\(Endpoints.apiKeyParam)&session_id=\(Auth.sessionId)"
            case .posterImage(let posterPath): return "https://image.tmdb.org/t/p/w500\(posterPath)"
            }
        }
        
        var url: URL {
            return URL(string: stringValue)!
        }
    }
    
    class func getFavorites(completion: @escaping ([Movie]?, Error?) -> Void) {
        taskForGETRequest(url: Endpoints.getFavorites.url, response: MovieResults.self) { (response, error) in
            if let response = response {
                completion(response.results, nil)
            
            } else {
                completion(nil, error)
            }
        }
    }
    
    class func downloadPosterImage(path: String, completion: @escaping (Data?, Error?) -> Void) {
        let task =
            URLSession.shared.dataTask(with: Endpoints.posterImage(path).url) {
                (data, response, error) in
                DispatchQueue.main.async {
                    completion(data, error)
                }
        }
        
        task.resume()
    }
    
    class func getRequestToken(completion: @escaping (Bool, Error?) -> Void) {
        taskForGETRequest(url: Endpoints.getRequestToken.url, response: RequestTokenResponse.self) { (response, error) in
            if let response = response {
                Auth.requestToken = response.requestToken
                completion(true, nil)
            
            } else {
                completion(false, nil)
            }
        }
    }
    
    class func search(query: String, completion: @escaping ([Movie], Error?) -> Void) -> URLSessionTask {
        let task = taskForGETRequest(url: Endpoints.search(query).url, response: MovieResults.self) { (response, error) in
            if let response = response {
                completion(response.results, nil)
            
            } else {
                completion([], error)
            }
        }
        
        return task
    }
    
    class func taskForGETRequest<T: Decodable>(url: URL, response: T.Type, completion: @escaping (T?, Error?) -> Void) -> URLSessionTask {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                
                return
            }
            
            let decoder = JSONDecoder()
            do {
                let responseObject = try decoder.decode(T.self, from: data)
                
                DispatchQueue.main.async {
                    completion(responseObject, nil)
                }
                
            } catch {
                do {
                    let errorResponse = try decoder.decode(TMDBResponse.self, from: data) as Error
                    
                    DispatchQueue.main.async {
                        completion(nil, errorResponse)
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
                
            }
        }
        
        task.resume()
        
        return task
    }
    
    class func taskForPOSTRequest<RequestType: Encodable, ResponseType: Decodable>(url: URL, body: RequestType, response: ResponseType.Type,completion: @escaping (ResponseType?, Error?) -> Void) {
        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content_Type")
        request.httpBody = try! JSONEncoder().encode(body)
        
        let task = URLSession.shared.dataTask(with: request) {
            data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                
                return
            }
            
            let decoder = JSONDecoder()
            
            do {
                let responseObject = try decoder.decode(ResponseType.self, from: data)
                DispatchQueue.main.async {
                    completion(responseObject, nil)
                }
                
            } catch {
                do {
                    let errorResponse = try decoder.decode(TMDBResponse.self, from: data) as Error
                    
                    DispatchQueue.main.async {
                        completion(nil, errorResponse)
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            }
        }
        
        task.resume()
    }
    
    class func markWatchlist(movieID: Int, watchlist: Bool, completion: @escaping (Bool, Error?) -> Void) {
        let body = MarkWatchlist(mediaType: "movie", mediaID: movieID, watchlist: watchlist)
        
        taskForPOSTRequest(url: Endpoints.markWatchlist.url, body: body, response: TMDBResponse.self) { (response, error) in
            if let response = response {
                completion(
                    response.statusCode == 1 ||
                        response.statusCode == 12 ||
                        response.statusCode == 13,
                    nil)
            }
        }
    }
    
    class func createSession(completion: @escaping (Bool, Error?) -> Void) {
        let body = PostSession(requestToken: Auth.requestToken)
        
        taskForPOSTRequest(url: Endpoints.createSession.url, body: body, response: SessionResponse.self) { (responseObject, error) in
            if let responseObject = responseObject {
                Auth.sessionId = responseObject.sessionID
                completion(true, nil)
            } else {
                completion(false, nil)
            }
        }
    }
    
    class func logout(completion: @escaping (Bool, Error?) -> Void) {
        var request = URLRequest(url: Endpoints.logOut.url)
        request.httpMethod = "DELETE"
        request.httpBody = try! JSONEncoder().encode(LogoutRequest(sessionID: Auth.sessionId))
        request.addValue("application/json", forHTTPHeaderField: "Content_Type")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let _ = data else {
                completion(false, error)
                
                return
            }
            
            Auth.requestToken = ""
            Auth.sessionId = ""
            
            completion(true, nil)
        }
        
        task.resume()
    }
    
    class func login(username: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        let body = LoginRequest(username: username, password: password, requestToken: Auth.requestToken)
        
        taskForPOSTRequest(url: Endpoints.login.url, body: body, response: RequestTokenResponse.self) { (responseObject, error) in
            if let responseObject = responseObject {
                Auth.requestToken = responseObject.requestToken
                completion(true, nil)
            } else {
                completion(false, error)
            }
        }
    }
    
    class func markFavorite(movieID: Int, favorite: Bool, completion: @escaping (Bool, Error?) -> Void) {
        let body = MarkFavorite(mediaType: "movie", mediaID: movieID, favorite: favorite)
        
        taskForPOSTRequest(url: Endpoints.markFavorite.url, body: body, response: TMDBResponse.self) { (response, error) in
            if let response = response {
                completion(response.statusCode == 1 ||
                    response.statusCode == 12 ||
                    response.statusCode == 13,
                           nil)
            }
        }
    }
        
        class func getWatchlist(completion: @escaping ([Movie], Error?) -> Void) {
        taskForGETRequest(url: Endpoints.getWatchlist.url, response: MovieResults.self) { (response, error) in
            if let response = response {
                completion(response.results, nil)
            }
        }
    }
}
