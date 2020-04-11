//
//  HttpClient.swift
//  Network
//
//  Created by Nick on 4/11/20.
//  Copyright © 2020 kciNniL. All rights reserved.
//

import Foundation

struct HTTPClient {

    let session: URLSession
    
    // TODO: - Mock URLSession To Test
    // TODO: - insert certificate pinning
    // TODO: - insert Plugin func willSend(_ request: URLRequest) / func didReceive(_ result: (Data?, URLResponse?, Error?))
    
    init(session: URLSession) {
        self.session = session
    }

    func send<Req: Request>(_ request: Req, decisions: [Decision]? = nil, handler: @escaping (Result<Req.Response, Error>) -> Void) {
        
        let urlRequest: URLRequest
        do {
            urlRequest = try request.buildRequest()
        } catch {
            handler(.failure(error))
            return
        }
        
        session.dataTask(with: urlRequest) { data, response, error in
            
            guard let data = data else {
                handler(.failure(error ?? ResponseError.nilData))
                return
            }
            
            guard let response = response as? HTTPURLResponse else {
                handler(.failure(ResponseError.nonHTTPResponse))
                return
            }
            
            self.handleDecision(request, data: data, response: response, decisions: decisions ?? request.decisions, handler: handler)
        }.resume()
    }
    
    private
    func handleDecision<Req: Request>(_ request: Req, data: Data, response: HTTPURLResponse, decisions: [Decision], handler: @escaping (Result<Req.Response, Error>) -> Void) {
        
        if decisions.isEmpty {
            fatalError("No decision left but did not reach a stop.")
        }
        
        var decisions = decisions
        let currentDecision = decisions.removeFirst()
        
        if !currentDecision.shouldApply(request: request, data: data, response: response) {
            handleDecision(request, data: data, response: response, decisions: decisions, handler: handler)
            return
        }

        currentDecision.apply(request: request, data: data, response: response) { action in
            switch action {
            case .next(let data, let response):
                self.handleDecision(request, data: data, response: response, decisions: decisions, handler: handler)
            case .restart(let decisions):
                self.send(request, decisions: decisions, handler: handler)
            case .errored(let error):
                handler(.failure(error))
            case .done(let value):
                handler(.success(value))
            }
        }
    }

}