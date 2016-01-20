//
//  APIObjectiveC.swift
//  PostmatesNetworking
//
//  Created by Kevin Ballard on 12/31/15.
//  Copyright © 2015 Postmates. All rights reserved.
//

// obj-c helpers
extension APIManager {
    /// The default `APIManager` instance.
    @objc(defaultManager) public static var __objc_defaultManager: APIManager {
        return API
    }
    
    /// Creates a POST request.
    /// - Parameter path: The path for the request, interpreted relative to the
    ///   environment. May be an absolute URL.
    /// - Parameter json: The JSON-compatible object to upload as the body of the request.
    /// - Returns: An `APIManagerUploadJSONRequest`, or `nil` if the `path` cannot
    ///   be parsed by `NSURL` or `json` is not a JSON-compatible object.
    @objc(requestForPOST:json:)
    public func __objc_requestForPOST(path: String, json object: AnyObject) -> APIManagerUploadJSONRequest! {
        guard let json = try? JSON(plist: object) else { return nil }
        return request(POST: path, json: json)
    }
}

extension APIManagerError {
    /// Returns an `NSError` using the PMAPIError constants for use by Objective-C.
    /// The returned error cannot bridge back into Swift, but it contains a usable `userInfo`.
    internal func toNSError() -> NSError {
        switch self {
        case let .FailedResponse(statusCode, body):
            let statusString = NSHTTPURLResponse.localizedStringForStatusCode(statusCode)
            return NSError(domain: PMAPIErrorDomain, code: PMAPIError.FailedResponse.rawValue, userInfo: [
                NSLocalizedDescriptionKey: "HTTP response indicated failure (\(statusCode) \(statusString))",
                PMAPIStatusCodeErrorKey: statusCode,
                PMAPIBodyDataErrorKey: body
                ])
        case let .UnexpectedContentType(contentType, body):
            return NSError(domain: PMAPIErrorDomain, code: PMAPIError.UnexpectedContentType.rawValue, userInfo: [
                NSLocalizedDescriptionKey: "HTTP response had unexpected content type \(String(reflecting: contentType))",
                PMAPIContentTypeErrorKey: contentType,
                PMAPIBodyDataErrorKey: body
                ])
        case .UnexpectedNoContent:
            return NSError(domain: PMAPIErrorDomain, code: PMAPIError.UnexpectedNoContent.rawValue, userInfo: [
                NSLocalizedDescriptionKey: "HTTP response returned 204 No Content when an entity was expected"
                ])
        case let .UnexpectedRedirect(statusCode, location, body):
            let statusString = NSHTTPURLResponse.localizedStringForStatusCode(statusCode)
            var userInfo = [
                NSLocalizedDescriptionKey: "HTTP response returned a redirection (\(statusCode) \(statusString)) when an entity was expected",
                PMAPIStatusCodeErrorKey: statusCode,
                PMAPIBodyDataErrorKey: body
            ]
            if let location = location {
                userInfo[PMAPILocationErrorKey] = location
            }
            return NSError(domain: PMAPIErrorDomain, code: PMAPIError.UnexpectedRedirect.rawValue, userInfo: userInfo)
        }
    }
}

// MARK: - Result

/// The results of an API request.
public class PMAPIResult: NSObject, NSCopying {
    /// `true` iff the task finished successfully.
    public let isSuccess: Bool
    
    /// `true` iff the task failed with an error.
    public var isError: Bool {
        return error != nil
    }
    
    /// `true` iff the task was canceled before it finished.
    public var isCanceled: Bool {
        return !isSuccess && error == nil
    }
    
    /// If the task finished successfully, returns the resulting value, if any.
    /// Otherwise, returns `nil`.
    /// - Note: A successful result may still have a `nil` value if the parse handler
    ///   returns `nil` or if it's a DELETE request and the response is 204 No Content.
    public let value: AnyObject?
    
    /// If the task finished successfully, or if it failed with an error
    /// during processing after receiving the response, returns the `NSURLResponse`.
    /// Otherwise, if the task failed with a networking error or was canceled,
    /// returns `nil`.
    public let response: NSURLResponse?
    
    /// If the task failed with an error, returns the `NSError`.
    /// Otherwise, returns `nil`.
    /// - Note: Canceled tasks are not considered to be in error and therefore
    ///   return `nil` from both `value` and `error`.
    public let error: NSError?
    
    /// Creates and returns a new `PMAPIResult` representing a successful result.
    public init(value: AnyObject?, response: NSURLResponse) {
        isSuccess = true
        self.value = value
        self.response = response
        error = nil
        super.init()
    }
    
    /// Creates and returns a new `PMAPIResult` representing a failed task.
    public init(error: NSError, response: NSURLResponse?) {
        isSuccess = false
        self.error = error
        self.response = response
        value = nil
        super.init()
    }
    
    /// Creates and returns a new `PMAPIResult` representing a canceled task.
    public class func canceledResult() -> PMAPIResult {
        return PMAPIResult(canceled: ())
    }
    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        return self
    }
    
    private init(canceled: ()) {
        isSuccess = false
        value = nil
        response = nil
        error = nil
        super.init()
    }
    
    private convenience init<T: AnyObject>(result: APIManagerTaskResult<T>) {
        switch result {
        case let .Success(response, value):
            self.init(value: value, response: response)
        case let .Error(response, error as APIManagerError):
            self.init(error: error.toNSError(), response: response)
        case let .Error(response, error):
            self.init(error: error as NSError, response: response)
        case .Canceled:
            self.init(canceled: ())
        }
    }
    
    private convenience init<T: AnyObject>(result: APIManagerTaskResult<T?>) {
        switch result {
        case let .Success(response, value):
            self.init(value: value, response: response)
        case let .Error(response, error as APIManagerError):
            self.init(error: error.toNSError(), response: response)
        case let .Error(response, error):
            self.init(error: error as NSError, response: response)
        case .Canceled:
            self.init(canceled: ())
        }
    }
}

/// The results of an API request that returns an `NSData`.
public final class PMAPIDataResult: PMAPIResult {
    /// If the task finished successfully, returns the resulting `NSData`, if any.
    /// Otherwise, returns `nil`.
    /// - Note: A successful result may still have a `nil` value if it's a DELETE
    /// request and the response is 204 No Content.
    /// - Note: This property returns the same value that `value` does.
    public var data: NSData? {
        return value as! NSData?
    }
    
    /// Creates and returns a new `PMAPIDataResult` representing a successful result.
    public init(data: NSData?, response: NSURLResponse) {
        super.init(value: data, response: response)
    }
    
    /// Creates and returns a new `PMAPIDataResult` representing a failed task.
    public override init(error: NSError, response: NSURLResponse?) {
        super.init(error: error, response: response)
    }
    
    /// Creates and returns a new `PMAPIDataResult` representing a canceled task.
    public override class func canceledResult() -> PMAPIDataResult {
        return PMAPIDataResult(canceled: ())
    }
    
    private override init(canceled: ()) {
        super.init(canceled: ())
    }
    
    private convenience init(result: APIManagerTaskResult<NSData>) {
        switch result {
        case let .Success(response, data):
            self.init(data: data, response: response)
        case let .Error(response, error as APIManagerError):
            self.init(error: error.toNSError(), response: response)
        case let .Error(response, error):
            self.init(error: error as NSError, response: response)
        case .Canceled:
            self.init(canceled: ())
        }
    }
    
    private convenience init(result: APIManagerTaskResult<NSData?>) {
        switch result {
        case let .Success(response, data):
            self.init(data: data, response: response)
        case let .Error(response, error as APIManagerError):
            self.init(error: error.toNSError(), response: response)
        case let .Error(response, error):
            self.init(error: error as NSError, response: response)
        case .Canceled:
            self.init(canceled: ())
        }
    }
}

// MARK: - Request

extension APIManagerRequest {
    /// The request method.
    @objc(requestMethod) public var __objc_requestMethod: String {
        return requestMethod.rawValue
    }
    
    /// The timeout interval of the request, in seconds. If `nil`, the session's default
    /// timeout interval is used. Default is `nil`.
    @objc(timeoutInterval) public var __objc_timeoutInterval: NSNumber? {
        get { return timeoutInterval }
        set { timeoutInterval = newValue as NSTimeInterval? }
    }
    
    /// The cache policy to use for the request. If `NSURLRequestUseProtocolCachePolicy`,
    /// the default cache policy is used. Default is `NSURLRequestUseProtocolCachePolicy`.
    @objc(cachePolicy) public var __objc_cachePolicy: NSURLRequestCachePolicy {
        get { return cachePolicy ?? NSURLRequestCachePolicy.UseProtocolCachePolicy }
        set {
            if newValue == NSURLRequestCachePolicy.UseProtocolCachePolicy {
                cachePolicy = nil
            } else {
                cachePolicy = newValue
            }
        }
    }
    
    /// Additional HTTP header fields to pass in the request. Default is `[:]`.
    ///
    /// If not specified, the request will fill in `Accept` and `Accept-Language`
    /// automatically when performing the request.
    ///
    /// - Note: If `self.credential` is non-`nil`, the `Authorization` header will be
    /// ignored. `Content-Type` and `Content-Length` are always ignored.
    @objc(headerFields) public var __objc_headerFields: [String: String] {
        return headerFields.dictionary
    }
    
    /// Adds an HTTP header to the list of header fields.
    ///
    /// - Parameter value: The value for the header field.
    /// - Parameter field: The name of the header field. Header fields are case-insensitive.
    ///
    /// If a value was previously set for the specified *field*, the supplied *value* is appended
    /// to the existing value using the appropriate field delimiter.
    @objc(addValue:forHeaderField:) public func __objc_addValue(value: String, forHeaderField field: String) {
        headerFields.addValue(value, forHeaderField: field)
    }
    
    /// Sets a specified HTTP header field.
    ///
    /// - Parameter value: The value for the header field.
    /// - Parameter field: The name of the header field. Header fields are case-insensitive.
    @objc(setValue:forHeaderField:) public func __objc_setValue(value: String, forHeaderField field: String) {
        headerFields[field] = value
    }
    
    /// Returns a specified HTTP header field, if set.
    ///
    /// - Parameter field: The name of the header field. Header fields are case-insensitive.
    /// - Returns: The value for the header field, or `nil` if no value was set.
    @objc(valueForHeaderField:) public func __objc_valueForHeaderField(field: String) -> String? {
        return headerFields[field]
    }
}

// MARK: - Network Request

extension APIManagerNetworkRequest {
    /// Performs an asynchronous request and calls the specified handler when
    /// done.
    /// - Parameter handler: The handler to call when the request is done. This
    ///   handler is not guaranteed to be called on any particular thread.
    /// - Returns: An `APIManagerTask` that represents the operation.
    @objc(performRequestWithCompletion:)
    public func __objc_performRequestWithCompletion(handler: @convention(block) (task: APIManagerTask, result: PMAPIDataResult) -> Void) -> APIManagerTask {
        return performRequestWithCompletion { task, result in
            handler(task: task, result: PMAPIDataResult(result: result))
        }
    }
    
    /// Performs an asynchronous request and calls the specified handler when
    /// done.
    /// - Parameter queue: The queue to call the handler on.
    /// - Parameter handler: The handler to call when the request is done. This
    /// handler is called on *queue*.
    /// - Returns: An `APIManagerTask` that represents the operation.
    @objc(performRequestWithCompletionOnQueue:handler:)
    public func __objc_performRequestWithCompletionOnQueue(queue: NSOperationQueue, handler: @convention(block) (task: APIManagerTask, result: PMAPIDataResult) -> Void) -> APIManagerTask {
        return performRequestWithCompletionOnQueue(queue) { task, result in
            handler(task: task, result: PMAPIDataResult(result: result))
        }
    }
}

// MARK: - Data Request

extension APIManagerDataRequest {
    /// Returns a new request that parses the data as JSON.
    /// Any nulls in the JSON are represented as `NSNull`.
    /// - Returns: An `APIManagerObjectParseRequest`.
    @objc(parseAsJSON)
    public func __objc_parseAsJSON() -> APIManagerObjectParseRequest {
        return __objc_parseAsJSONOmitNulls(false)
    }
    
    /// Returns a new request that parses the data as JSON.
    /// - Parameter omitNulls: If `true`, nulls in the JSON are omitted from the result.
    ///   If `false`, nulls are represented as `NSNull`. If the top-level value is null,
    ///   it is always represented as `NSNull` regardless of this parameter.
    /// - Returns: An `APIManagerObjectParseRequest`.
    @objc(parseAsJSONOmitNulls:)
    public func __objc_parseAsJSONOmitNulls(omitNulls: Bool) -> APIManagerObjectParseRequest {
        return APIManagerObjectParseRequest(request: parseAsJSONWithHandler({ response, json -> AnyObject? in
            return omitNulls ? (json.plistNoNull ?? NSNull()) : json.plist
        }))
    }
    
    /// Returns a new request that parses the data as JSON and passes it through
    /// the specified handler. Any nulls in the JSON are represented as `NSNull`.
    /// - Parameter handler: The handler to call as part of the request
    ///   processing. This handler is not guaranteed to be called on any
    ///   particular thread. The handler returns the new value for the request.
    ///   If the handler returns `nil`, then if `error` is filled in with an
    ///   error the parse is considered to have errored, otherwise the parse is
    ///   treated as successful but with a `nil` value.
    /// - Returns: An `APIManagerObjectParseRequest`.
    /// - Note: If you need to parse on a particular thread, such as on the main
    ///   thread, you should just use `performRequestWithCompletion(_:)`
    ///   instead.
    /// - Note: If the request is canceled, the results of the handler may be
    ///   discarded. Any side-effects performed by your handler must be safe in
    ///   the event of a cancelation.
    @objc(parseAsJSONWithHandler:)
    public func __objc_parseAsJSONWithHandler(handler: @convention(block) (response: NSURLResponse, json: AnyObject, error: NSErrorPointer) -> AnyObject?) -> APIManagerObjectParseRequest {
        return __objc_parseAsJSONOmitNulls(false, withHandler: handler)
    }
    
    /// Returns a new request that parses the data as JSON and passes it through
    /// the specified handler.
    /// - Parameter omitNulls: If `true`, nulls in the JSON are omitted from the result.
    ///   If `false`, nulls are represented as `NSNull`. If the top-level value is null,
    ///   it is always represented as `NSNull` regardless of this parameter.
    /// - Parameter handler: The handler to call as part of the request
    ///   processing. This handler is not guaranteed to be called on any
    ///   particular thread. The handler returns the new value for the request.
    ///   If the handler returns `nil`, then if `error` is filled in with an
    ///   error the parse is considered to have errored, otherwise the parse is
    ///   treated as successful but with a `nil` value.
    /// - Returns: An `APIManagerObjectParseRequest`.
    /// - Note: If you need to parse on a particular thread, such as on the main
    ///   thread, you should just use `performRequestWithCompletion(_:)`
    ///   instead.
    /// - Note: If the request is canceled, the results of the handler may be
    ///   discarded. Any side-effects performed by your handler must be safe in
    ///   the event of a cancelation.
    @objc(parseAsJSONOmitNulls:withHandler:)
    public func __objc_parseAsJSONOmitNulls(omitNulls: Bool, withHandler handler: @convention(block) (response: NSURLResponse, json: AnyObject, error: NSErrorPointer) -> AnyObject?) -> APIManagerObjectParseRequest {
        return APIManagerObjectParseRequest(request: parseAsJSONWithHandler({ response, json -> AnyObject? in
            var error: NSError?
            let jsonObject = omitNulls ? (json.plistNoNull ?? NSNull()) : json.plist
            if let object = handler(response: response, json: jsonObject, error: &error) {
                return object
            } else if let error = error {
                throw error
            } else {
                return nil
            }
        }))
    }
    
    /// Returns a new request that parses the data with the specified handler.
    /// - Parameter handler: The handler to call as part of the request
    ///   processing. This handler is not guaranteed to be called on any
    ///   particular thread. The handler returns the new value for the request.
    ///   If the handler returns `nil`, then if `error` is filled in with an
    ///   error the parse is considered to have errored, otherwise the parse is
    ///   treated as successful but with a `nil` value.
    /// - Returns: An `APIManagerObjectParseRequest`.
    /// - Note: If you need to parse on a particular thread, such as on the main
    ///   thread, you should just use `performRequestWithCompletion(_:)`
    ///   instead.
    /// - Note: If the request is canceled, the results of the handler may be
    ///   discarded. Any side-effects performed by your handler must be safe in
    ///   the event of a cancelation.
    @objc(parseWithHandler:)
    public func __objc_parseWithHandler(handler: @convention(block) (response: NSURLResponse, data: NSData, error: NSErrorPointer) -> AnyObject?) -> APIManagerObjectParseRequest {
        return APIManagerObjectParseRequest(request: parseWithHandler({ response, data -> AnyObject? in
            var error: NSError?
            if let object = handler(response: response, data: data, error: &error) {
                return object
            } else if let error = error {
                throw error
            } else {
                return nil
            }
        }))
    }
}

// MARK: - Object Parse Request

/// An HTTP API request that has a parse handler.
///
/// - Note: This class is only meant to be used from Obj-C.
public final class APIManagerObjectParseRequest: APIManagerRequest {
    // FIXME: Swift 2.2: Add - recommended: doc comment field
    
    // NB: All mutable properties need to be overridden here
    
    public override var url: NSURL {
        return _request.url
    }
    
    public override var parameters: [NSURLQueryItem] {
        return _request.parameters
    }
    
    public override var credential: NSURLCredential? {
        get { return _request.credential }
        set { _request.credential = newValue }
    }
    
    public override var timeoutInterval: NSTimeInterval? {
        get { return _request.timeoutInterval }
        set { _request.timeoutInterval = newValue }
    }
    
    public override var cachePolicy: NSURLRequestCachePolicy? {
        get { return _request.cachePolicy }
        set { _request.cachePolicy = newValue }
    }
    
    public override var shouldFollowRedirects: Bool {
        get { return _request.shouldFollowRedirects }
        set { _request.shouldFollowRedirects = newValue }
    }
    
    public override var contentType: String {
        return _request.contentType
    }
    
    public override var allowsCellularAccess: Bool {
        get { return _request.allowsCellularAccess }
        set { _request.allowsCellularAccess = newValue }
    }
    
    public override var userInitiated: Bool {
        get { return _request.userInitiated }
        set { _request.userInitiated = newValue }
    }
    
    #if os(iOS)
    public override var affectsNetworkActivityIndicator: Bool {
        get { return _request.affectsNetworkActivityIndicator }
        set { _request.affectsNetworkActivityIndicator = newValue }
    }
    #endif
    
    public override var headerFields: HTTPHeaders {
        get { return _request.headerFields }
        set { _request.headerFields = newValue }
    }
    
    /// The expected Content-Type of the response. Defaults to `["application/json"]` for
    /// JSON parse requests, or `[]` for requests created with `parseWithHandler()`.
    ///
    /// This property is used to generate the `Accept` header, if not otherwise specified by
    /// the request. If multiple values are provided, they're treated as a priority list
    /// for the purposes of the `Accept` header.
    ///
    /// This property is also used to validate the `Content-Type` of the response. If the
    /// response is a 204 No Content, the `Content-Type` is not checked. For all other 2xx
    /// responses, if at least one expected content type is provided, the `Content-Type`
    /// header must match one of them. If it doesn't match any, the parse handler will be
    /// skipped and `APIManagerError.UnexpectedContentType` will be returned as the result.
    ///
    /// - Note: An empty or missing `Content-Type` header is treated as matching.
    ///
    /// Each media type in the list may include parameters. These parameters will be included
    /// in the `Accept` header, but will be ignored for the purposes of comparing against the
    /// resulting `Content-Type` header. If the media type includes a parameter named `q`,
    /// this parameter should be last, as it will be interpreted by the `Accept` header as
    /// the priority instead of as a parameter of the media type.
    ///
    /// - Important: The media types in this list will not be checked for validity. They must
    ///   follow the rules for well-formed media types, otherwise the server may handle the
    ///   request incorrectly.
    public var expectedContentTypes: [String] {
        get { return _request.expectedContentTypes }
        set { _request.expectedContentTypes = newValue }
    }
    
    /// Performs an asynchronous request and calls the specified handler when
    /// done.
    /// - Parameter handler: The handler to call when the requeset is done. This
    ///   handler is not guaranteed to be called on any particular thread.
    /// - Returns: An `APIManagerTask` that represents the operation.
    public func performRequestWithCompletion(handler: @convention(block) (task: APIManagerTask, result: PMAPIResult) -> Void) -> APIManagerTask {
        return _request.performRequestWithCompletion{ task, result in
            handler(task: task, result: PMAPIResult(result: result))
        }
    }
    
    /// Performs an asynchronous request and calls the specified handler when
    /// done.
    /// - Parameter queue: The queue to call the handler on.
    /// - Parameter handler: The handler to call when the request is done. This
    /// handler is called on *queue*.
    /// - Returns: An `APIManagerTask` that represents the operation.
    public func performRequestWithCompletionOnQueue(queue: NSOperationQueue, handler: @convention(block) (task: APIManagerTask, result: PMAPIResult) -> Void) -> APIManagerTask {
        return _request.performRequestWithCompletionOnQueue(queue) { task, result in
            handler(task: task, result: PMAPIResult(result: result))
        }
    }
    
    private let _request: APIManagerParseRequest<AnyObject?>
    
    private init(request: APIManagerParseRequest<AnyObject?>) {
        _request = request
        super.init(apiManager: request.apiManager, URL: request.baseURL, method: request.requestMethod, parameters: [])
    }

    public required init(__copyOfRequest request: APIManagerRequest) {
        let request: APIManagerObjectParseRequest = unsafeDowncast(request)
        _request = APIManagerParseRequest(__copyOfRequest: request._request)
        super.init(__copyOfRequest: request)
    }
    
    internal override func prepareURLRequest() -> (NSMutableURLRequest -> Void)? {
        return _request.prepareURLRequest()
    }
}
