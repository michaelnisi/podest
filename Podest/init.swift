//
//  init.swift
//  Podest
//
//  Initializing shared state
//
//  Created by Michael Nisi on 24/04/16.
//  Copyright © 2016 Michael Nisi. All rights reserved.
//

import FanboyKit
import FeedKit
import Foundation
import MangerKit
import Ola
import Patron
import Skull
import os.log
import Playback

private let log = OSLog.disabled

// MARK: - Search Repository

/// Returns additional HTTP headers for `service`.
private func httpAdditionalHeaders(service: Service) -> [AnyHashable : Any]? {
  guard
    let userPasswordString = service.secret,
    let userPasswordData = userPasswordString.data(using: .utf8) else {
    return nil
  }

  let base64EncodedCredential = userPasswordData.base64EncodedString()
  let auth = "Basic \(base64EncodedCredential)"

  return ["Authorization" : auth]
}

private func makeFanboySession(service: Service) -> URLSession {
  let conf = URLSessionConfiguration.default

  conf.httpShouldUsePipelining = true
  conf.requestCachePolicy = .useProtocolCachePolicy
  conf.httpAdditionalHeaders = httpAdditionalHeaders(service: service)

  return URLSession(configuration: conf)
}

private func makeFanboyService(options: Service) -> FanboyService {
  let url = URL(string: options.url)!
  let session = makeFanboySession(service: options)
  let log = OSLog.disabled
  let client = Patron(URL: url as URL, session: session, log: log)

  return Fanboy(client: client)
}

private func makeSearchRepo(_ conf: Config) throws -> SearchRepository {
  let c = conf.feedCache
  let opts = conf.service("production", at: "*")!
  let svc = makeFanboyService(options: opts)

  let queue = OperationQueue()
  queue.maxConcurrentOperationCount = 1

  return SearchRepository(
    cache: c,
    svc: svc,
    browser: conf.browser,
    queue: queue
  )
}

// MARK: - Feed Repository

/// Returns a new URL session for the Manger service.
///
/// Adjusting timeout to fit into the 30 seconds time window allowed for
/// background fetching, leaving some space for other tasks. It would probably
/// be advisable to use two different timeout intervals, the default and a
/// shorter one for background fetching. Try this if 0x8badf00d appears in the
/// crash logs. On the other hand, 10 seconds seems long enough.
private func makeMangerSession(service: Service) -> URLSession {
  let conf = URLSessionConfiguration.default

  conf.httpShouldUsePipelining = true
  conf.requestCachePolicy = .useProtocolCachePolicy
  conf.httpAdditionalHeaders = httpAdditionalHeaders(service: service)
  conf.timeoutIntervalForResource = 20

  return URLSession(configuration: conf)
}

private func makeMangerService(options: Service) -> MangerService {
  let url = URL(string: options.url)!
  let session = makeMangerSession(service: options)
  let log = OSLog.disabled
  let client = Patron(URL: url, session: session, log: log)

  return Manger(client: client)
}

private func makeFeedRepo(_ conf: Config) throws -> FeedRepository {
  let c = conf.feedCache
  let opts = conf.service("production", at: "*")!
  let svc = makeMangerService(options: opts)
  let queue = OperationQueue()

  return FeedRepository(cache: c, svc: svc, queue: queue)
}

// MARK: - Caches

private func createDirectory(_ dir: URL) {
  do {
    try FileManager.default
      .createDirectory(at: dir, withIntermediateDirectories: false)
  } catch {
    let er = error as NSError

    switch (er.domain, er.code) {
    case (NSCocoaErrorDomain, 516): // file exists
      break
    default:
      fatalError(String(describing: error))
    }
  }
}

private func removeFile(at url: URL) {
  do {
    os_log("removing file: %@",
           log: log, type: .info, url.path)
    try FileManager.default.removeItem(at: url)
  } catch {
    os_log("failed to remove file: %@",
           log: log, type: .error, error as CVarArg)
  }
}

private func makeCache(_ conf: Config) -> FeedCache {
  let bundle = Bundle(for: FeedCache.self)
  let schema = bundle.path(forResource: "cache", ofType: "sql")!
  let name = Bundle.main.bundleIdentifier!

  let dir = try! FileManager.default.url(
    for: .cachesDirectory,
    in: .userDomainMask,
    appropriateFor: nil,
    create: true
  ).appendingPathComponent(name, isDirectory: true)

  // Not naming it Cache.db to avoid conflicts with URLCache.
  let url = URL(string: "Feeds.db", relativeTo: dir)!

  if conf.settings.flush {
    removeFile(at: url)
  }

  createDirectory(dir)

  os_log("cache database at: %@",
         log: log, type: .info, url.path)

  return try! FeedCache(schema: schema, url: url)
}

private func makeUserCache(_ conf: Config) -> UserCache {
  let bundle = Bundle(for: UserCache.self)
  let schema = bundle.path(forResource: "user", ofType: "sql")!
  let name = Bundle.main.bundleIdentifier!

  let dir = try!  FileManager.default.url(
    for: .applicationSupportDirectory,
    in: .userDomainMask,
    appropriateFor: nil,
    create: true
  ).appendingPathComponent(name, isDirectory: true)

  // All content in the .applicationSupportDirectory should be placed in a
  // custom subdirectory whose name is that of your app’s bundle identifier or
  // your company. In iOS, the contents of this directory are backed up by
  // iTunes and iCloud.

  let url = URL(string: "User.db", relativeTo: dir)!

  if conf.settings.flush {
    removeFile(at: url)
  }

  createDirectory(dir)
  os_log("user database at: %@", log: log, type: .info, url.path)
  let cache = try! UserCache(schema: schema, url: url)

  return cache
}

// MARK: - Internals

private struct Service: Equatable, Decodable {
  let name: String
  let secret: String?
  let url: String
  let version: String

  static func ==(lhs: Service, rhs: Service) -> Bool {
    return lhs.name == rhs.name && lhs.version == rhs.version
  }
}

private final class Services: Decodable {
  var services: [Service]
  var contact: Contact

  func service(_ name: String, at version: String) -> Service? {
    return services.filter { svc in
      svc.name == name && svc.version == version
    }.first
  }
}

/// Additional **development** settings may override user defaults.
struct Settings {

  /// Despite disabling iCloud in Settings.app makes the better, more realistic,
  /// environment, this argument can be used during development. Passing `true`
  /// produces a NOP iCloud client at initialization time.
  let noSync: Bool

  /// Removes local caches for starting over.
  let flush: Bool

  /// Prevents automatic downloading of media files. Good for quick sessions in
  /// simulators, where background downloads may be pointless.
  let noDownloading: Bool

  /// Overrides allowed interface orientations, allowing all but upside down.
  let allButUpsideDown: Bool

}

/// Extending user defaults with our settings.
///
/// For preventing key collisions, all user defaults keys should be listed here,
/// which they aren’t at the moment. I’m looking at you, sync. Also, defaults
/// should be registered in AppDelegate.
///
/// The defaults are observable.
///
/// ```swift
/// let opts = [.initial, .new]
/// UserDefaults.standard.observe(\.automaticDownloads, options: opts) {
///   defaults, change in
/// }
/// ```
extension UserDefaults {

  static var automaticDownloadsKey = "automaticDownloads"
  static var mobileDataStreamingKey = "mobileDataStreaming"
  static var mobileDataDownloadsKey = "mobileDataDownloads"

  static var lastUpdateTimeKey = "ink.codes.podest.last-update"

  @objc dynamic var automaticDownloads: Bool {
    return bool(forKey: UserDefaults.automaticDownloadsKey)
  }

  @objc dynamic var mobileDataStreaming: Bool {
    return bool(forKey: UserDefaults.mobileDataStreamingKey)
  }

  @objc dynamic var mobileDataDownloads: Bool {
    return bool(forKey: UserDefaults.mobileDataDownloadsKey)
  }

  @objc dynamic var lastUpdateTimeKey: Double {
    return double(forKey: UserDefaults.lastUpdateTimeKey)
  }

}

/// The default to boot the app with. Eventual differences between
/// development and production should be configured in the JSON file.
final private class Config {

  fileprivate lazy var feedCache = makeCache(self)

  fileprivate lazy var browser: Browsing = try! makeFeedRepo(self)

  fileprivate let settings: Settings

  private let svcs: Services

  fileprivate func service(_ name: String, at version: String) -> Service? {
    return svcs.service(name, at: version)
  }

  fileprivate var contact: Contact {
    return svcs.contact
  }

  /// Initializes a new setup object with a provided URL of a local JSON
  /// configuration file.
  ///
  /// - Parameter url: The URL of the a local configuration file.
  init(url: URL) throws {
    let args = ProcessInfo.processInfo.arguments

    // Disabling sync also disables preloading media files.
    let noSync = args.contains("-ink.codes.podest.noSync")

    settings = Settings(
      noSync: noSync,
      flush: args.contains("-ink.codes.podest.flush"),
      noDownloading: args.contains("-ink.codes.podest.noDownloading") || noSync,
      allButUpsideDown: args.contains("-ink.codes.podest.allButUpsideDown")
    )

    os_log("settings: %{public}@", log: log, type: .info, String(describing: settings))

    let json = try! Data(contentsOf: url)
    
    svcs = try! JSONDecoder().decode(Services.self, from: json)
    os_log("services: %@", log: log, type: .info, svcs.services)

    if settings.flush {
      let keys = [
        UserDefaults.lastUpdateTimeKey
      ]
      for key in keys {
        UserDefaults.standard.removeObject(forKey: key)
        os_log("flushing: %{key}@", log: log, key)
      }
    }
  }

  fileprivate func freshSearchRepo() throws -> Searching {
    return try makeSearchRepo(self)
  }

  fileprivate func freshImageRepo() throws -> Images {
    return ImageRepository.shared
  }

  fileprivate lazy var userCache = makeUserCache(self)

  fileprivate func freshUserLibrary() throws -> UserLibrary {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1

    return UserLibrary(cache: userCache, browser: browser, queue: queue)
  }

  fileprivate lazy var user: UserLibrary = try! self.freshUserLibrary()

  fileprivate func makeUserClient() -> UserSyncing {
    guard !settings.noSync else {
      return NoUserClient()
    }

    let host = service("cloudkit", at: "*")!.url
    guard let probe = Ola(host: host) else {
      fatalError("could not init probe: \(host)")
    }

    let q = OperationQueue()
    q.name = "ink.codes.podest.sync"
    q.maxConcurrentOperationCount = 1

    let client = UserClient(cache: userCache, probe: probe, queue: q)

    if self.settings.flush {
      client.flush()
    }

    return client
  }

  fileprivate func makeStore() throws -> Shopping {
    let url = Bundle.main.url(forResource: "products", withExtension: "json")!
    let store = StoreFSM(url: url)

    return store
  }

  fileprivate func makeFileRepo() -> FileRepository {
    return FileRepository(userQueue: user)
  }
}

/// Hides `Ola` from indirect dependents, just wanting to to indicate network
/// activity.
private class NetworkIndicator: NetworkActivityIndicating {

  func increase() {
    NetworkActivityCounter.shared.increase()
  }

  func decrease() {
    NetworkActivityCounter.shared.decrease()
  }

}

// MARK: - Shared State

/// The static object graph of this application.
final class Podest {

  static let domain = "ink.codes.podest"
  static let scheme = "podest"

  private init() {}

  private static let conf: Config = {
    let bundle = Bundle(for: AppDelegate.classForCoder())
    let url = bundle.url(forResource: "config", withExtension: "json")!
    return try! Config(url: url)
  }()

  // MARK: Settings

  static let settings: Settings = conf.settings

  // MARK: Contact

  static let contact: Contact = conf.contact

  // MARK: Indicating Network Activity

  static let networkActivity: NetworkActivityIndicating = NetworkIndicator()

  // MARK: Resources

  static let images: Images = try! conf.freshImageRepo()

  // MARK: Discovering

  static let finder: Searching = try! conf.freshSearchRepo()
  static let browser: Browsing = conf.browser

  // MARK: User Specific

  static var userLibrary: Subscribing = conf.user
  static var userQueue: Queueing = conf.user

  // MARK: Caching

  static let userCaching: Caching = conf.userCache
  static let feedCaching: Caching = conf.feedCache

  // MARK: Syncing

  static let iCloud: UserSyncing = conf.makeUserClient()

  // MARK: Shopping

  static let store: Shopping = try! conf.makeStore()

  // MARK: Downloading

  static let files: Downloading = conf.makeFileRepo()

  // MARK: Playback

  static let playback: Playback = PlaybackSession(times: TimeRepository.shared)

}
