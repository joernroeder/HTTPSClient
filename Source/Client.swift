// Client.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@_exported import TCPSSL
@_exported import HTTPParser
@_exported import HTTPSerializer

public enum ClientError: ErrorProtocol {
    case httpsSchemeRequired
    case hostRequired
    case brokenConnection
}

public final class Client: Responder {
    public let host: String
    public let port: Int
    public let verifyBundle: String?
    public let certificate: String?
    public let privateKey: String?
    public let certificateChain: String?
    public let serializer: S4.RequestSerializer
    public let parser: S4.ResponseParser
    public let keepAlive: Bool
    public let connectionTimeout: Double
    public let requestTimeout: Double
    public let bufferSize: Int

    public var connection: C7.Connection?

    public init(uri: URI, configuration: ClientConfiguration = ClientConfiguration()) throws {
        guard let scheme = uri.scheme where scheme == "https" else {
            throw ClientError.httpsSchemeRequired
        }

        guard let host = uri.host else {
            throw ClientError.hostRequired
        }

        self.host = host
        self.port = uri.port ?? 443
        self.verifyBundle = configuration.verifyBundle
        self.certificate = configuration.certificate
        self.privateKey = configuration.privateKey
        self.certificateChain = configuration.certificateChain
        self.serializer = configuration.serializer
        self.parser = configuration.parser
        self.keepAlive = configuration.keepAlive
        self.connectionTimeout = configuration.connectionTimeout
        self.requestTimeout = configuration.requestTimeout
        self.bufferSize = configuration.bufferSize
    }

    public convenience init(uri: String, configuration: ClientConfiguration = ClientConfiguration()) throws {
        try self.init(uri: URI(uri), configuration: configuration)
    }
}

extension Client {
    private func addHeaders(to request: inout Request) {
        let port = (self.port == 443) ? "" : ":\(self.port)"
        request.host = "\(host)\(port)"
        //request.userAgent = "Zewo" // @see https://github.com/VeniceX/HTTPSClient/issues/24

        if !keepAlive && request.connection.isEmpty {
            request.connection = "close"
        }
    }

    public func respond(to request: Request) throws -> Response {
        var request = request
        addHeaders(to: &request)

        let connection: Connection

        if let c = self.connection {
            connection = c
        } else {
            connection = try TCPSSLConnection(
                host: host,
                port: port,
                verifyBundle: verifyBundle,
                certificate: certificate,
                privateKey: privateKey,
                certificateChain: certificateChain,
                SNIHostname: host,
                timingOut: now() + connectionTimeout
            )

            try connection.open(timingOut: now() + connectionTimeout)
            self.connection = connection
        }

        let requestDeadline = now() + requestTimeout

        // TODO: Add deadline... S4.RequestSerializer.serialize(_:to:timingOut:)
        try serializer.serialize(request, to: connection)

        while true {
            let data = try connection.receive(upTo: bufferSize, timingOut: requestDeadline)
            if let response = try parser.parse(data)  {

                if let didUpgrade = request.didUpgrade {
                    try didUpgrade(response, connection)
                }

                if !keepAlive {
                    self.connection = nil
                }

                return response
            } else if data.count == 0 {
                //no data received, connection got broken
                throw ClientError.brokenConnection
            }
        }
    }

    public func send(_ request: Request, middleware: Middleware...) throws -> Response {
        var request = request
        addHeaders(to: &request)
        return try middleware.chain(to: self).respond(to: request)
    }

    private func send(_ request: Request, middleware: [Middleware]) throws -> Response {
        var request = request
        addHeaders(to: &request)
        let response = try middleware.chain(to: self).respond(to: request)
        if 400..<600 ~= response.status.statusCode {
            //error response code, destroy the connection
            self.connection = nil
        }
        return response
    }
}

extension Client {
    public func send(method: Method, uri: String, headers: Headers = [:], body: Data = [], middleware: Middleware...) throws -> Response {
        return try send(method: method, uri: uri, headers: headers, body: body, middleware: middleware)
    }

    public func send(method: Method, uri: String, headers: Headers = [:], body: DataConvertible, middleware: Middleware...) throws -> Response {
        return try send(method: method, uri: uri, headers: headers, body: body, middleware: middleware)
    }
}

extension Client {
    public func get(_ uri: String, headers: Headers = [:], body: Data = [], middleware: Middleware...) throws -> Response {
        return try send(method: .get, uri: uri, headers: headers, body: body, middleware: middleware)
    }

    public func get(_ uri: String, headers: Headers = [:], body: DataConvertible, middleware: Middleware...) throws -> Response {
        return try send(method: .get, uri: uri, headers: headers, body: body, middleware: middleware)
    }
}

extension Client {
    public func post(_ uri: String, headers: Headers = [:], body: Data = [], middleware: Middleware...) throws -> Response {
        return try send(method: .post, uri: uri, headers: headers, body: body, middleware: middleware)
    }

    public func post(_ uri: String, headers: Headers = [:], body: DataConvertible, middleware: Middleware...) throws -> Response {
        return try send(method: .post, uri: uri, headers: headers, body: body, middleware: middleware)
    }
}

extension Client {
    public func put(_ uri: String, headers: Headers = [:], body: Data = [], middleware: Middleware...) throws -> Response {
        return try send(method: .put, uri: uri, headers: headers, body: body, middleware: middleware)
    }

    public func put(_ uri: String, headers: Headers = [:], body: DataConvertible, middleware: Middleware...) throws -> Response {
        return try send(method: .put, uri: uri, headers: headers, body: body, middleware: middleware)
    }
}

extension Client {
    public func patch(_ uri: String, headers: Headers = [:], body: Data = [], middleware: Middleware...) throws -> Response {
        return try send(method: .patch, uri: uri, headers: headers, body: body, middleware: middleware)
    }

    public func patch(_ uri: String, headers: Headers = [:], body: DataConvertible, middleware: Middleware...) throws -> Response {
        return try send(method: .patch, uri: uri, headers: headers, body: body, middleware: middleware)
    }
}

extension Client {
    public func delete(_ uri: String, headers: Headers = [:], body: Data = [], middleware: Middleware...) throws -> Response {
        return try send(method: .delete, uri: uri, headers: headers, body: body, middleware: middleware)
    }

    public func delete(_ uri: String, headers: Headers = [:], body: DataConvertible, middleware: Middleware...) throws -> Response {
        return try send(method: .delete, uri: uri, headers: headers, body: body, middleware: middleware)
    }
}

extension Client {
    private func send(method: Method, uri: String, headers: Headers = [:], body: Data = [], middleware: [Middleware]) throws -> Response {
        let request = try Request(method: method, uri: URI(uri), headers: headers, body: body)
        return try send(request, middleware: middleware)
    }

    private func send(method: Method, uri: String, headers: Headers = [:], body: DataConvertible, middleware: [Middleware]) throws -> Response {
        let request = try Request(method: method, uri: URI(uri), headers: headers, body: body.data)
        return try send(request, middleware: middleware)
    }
}

extension Request {
    public var connection: Header {
        get {
            return headers["Connection"] ?? []
        }

        set(connection) {
            headers["Connection"] = connection
        }
    }

    var host: String? {
        get {
            return headers["Host"].first
        }

        set(host) {
            headers["Host"] = host.map({Header($0)}) ?? []
        }
    }

    // Warning: The storage key has to be in sync with Zewo.HTTP's upgrade property.
    var didUpgrade: ((Response, Stream) throws -> Void)? {
        get {
            return storage["request-connection-upgrade"] as? (Response, Stream) throws -> Void
        }

        set(didUpgrade) {
            storage["request-connection-upgrade"] = didUpgrade
        }
    }

    var userAgent: String? {
        get {
            return headers["User-Agent"].first
        }

        set(userAgent) {
            headers["User-Agent"] = userAgent.map({Header($0)}) ?? []
        }
    }
}
