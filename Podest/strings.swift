//
//  strings.swift - format strings and attributed strings
//  Podest
//
//  Created by Michael Nisi on 07/08/16.
//  Copyright © 2016 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit
import os.log

private let log = OSLog.disabled

// MARK: - Summaries

protocol Summarizable: Hashable {
  var summary: String? { get }
  var title: String { get }
  var author: String? { get }
  var guid: String { get }
}

extension Entry: Summarizable {}

extension Feed: Summarizable {
  var guid: String {
    return self.url // Anything unique for NSCache.
  }
}

private struct SummaryAttributes {

  static var p: NSParagraphStyle = {
    var p = NSMutableParagraphStyle()

    p.lineSpacing = 2

    return p
  }()

  let title1: [NSAttributedString.Key: Any] = [
    .font: UIFontMetrics.default.scaledFont(for:
      .systemFont(ofSize: 29, weight: .bold)),
    .foregroundColor: UIColor.darkText,
    .paragraphStyle: p
  ]

  let h1: [NSAttributedString.Key: Any] = [
    .font: UIFontMetrics.default.scaledFont(for:
      .systemFont(ofSize: 19, weight: .bold)),
    .foregroundColor: UIColor.darkText,
    .paragraphStyle: p
  ]

  let body: [NSAttributedString.Key: Any] = [
    .font: UIFontMetrics.default.scaledFont(for:
      .systemFont(ofSize: 19, weight: .medium)),
    .foregroundColor: UIColor(named: "Asphalt")!,
    .paragraphStyle: p
  ]

}

/// Parses feeds and entries into attributed strings.
private struct Summary<Item> {
  let item: Item
  let items: NSCache<NSString, NSAttributedString>
  let attributes: SummaryAttributes

  func attribute(summary: String?) -> NSAttributedString {
    let html = HTMLAttributor()

    os_log("attributing: %@",
           log: log, type: .debug, String(describing: summary))

    let str: String = {
      guard let s = summary, s != "" else {
        return "Sorry, we have no summary for this item at this time."
      }

      return s
    }()

    do {
      let tree = try html.parse(str)

      var styles = HTMLAttributor.defaultStyles

      styles["root"] = attributes.body
      styles["a"] = attributes.body
      styles["h1"] = attributes.h1

      return try html.attributedString(tree, styles: styles)
    } catch {
      os_log("parsing summary failed: %@", log: log, error as CVarArg)
      return NSAttributedString(string: str, attributes: attributes.body)
    }
  }
}

extension Summary where Item: Summarizable {

  var attributedString: NSAttributedString {
    if let cached = items.object(forKey: item.guid as NSString) {
      return cached
    }

    let str = NSMutableAttributedString(
      string: item.title, attributes: attributes.title1)

    str.append(
      NSAttributedString(string: "\n\n", attributes: attributes.body))

    str.append(
      attribute(summary: item.summary))

    items.setObject(str, forKey: item.guid as NSString)

    return str
  }

}

// MARK: - Core

/// All static cached string formatting.
///
/// Why wouldn’t this be an instance, referenced from Podest, like
/// everything else? For localisation it probably would, no?
class StringRepository {

  private static var summaryAttributes = SummaryAttributes()

  static func purge() {
    durations.removeAllObjects()
    summaries.removeAllObjects()
    episodeCellSubtitles.removeAllObjects()
  }

}

// MARK: - Entries and Feeds

extension StringRepository {

  /// Cached summaries of feeds and entries.
  private static var summaries: NSCache<NSString, NSAttributedString> = {
    let cache = NSCache<NSString, NSAttributedString>()

    cache.countLimit = 512

    return cache
  }()

  /// Returns an attributed summary with headline.
  static func makeSummaryWithHeadline(feed: Feed) -> NSAttributedString {
    return Summary<Feed>(
      item: feed,
      items: summaries,
      attributes: summaryAttributes
    ).attributedString
  }

  /// Returns an attributed summary with headline.
  static func makeSummaryWithHeadline(entry: Entry) -> NSAttributedString {
    return Summary<Entry>(
      item: entry,
      items: summaries,
      attributes: summaryAttributes
    ).attributedString
  }

  /// Returns an attributed summary with headline.
  static func makeSummaryWithHeadline(info: ProductsDataSource.Info) -> NSAttributedString {
    return Summary<ProductsDataSource.Info>(
      item: info,
      items: summaries,
      attributes: summaryAttributes
    ).attributedString
  }

}

// MARK: - Times and Dates

extension StringRepository {

  private static var naturalDateFormatter: DateFormatter = {
    let df = DateFormatter()

    df.timeStyle = .none
    df.dateStyle = .medium

    let locale = Locale(identifier: "en_US")

    df.locale = locale
    df.doesRelativeDateFormatting = true

    return df
  }()

  static func string(from date: Date) -> String {
    return naturalDateFormatter.string(from: date)
  }

  private static var durations: NSCache<NSNumber, NSString> = {
    let c = NSCache<NSNumber, NSString>()

    c.countLimit = 1024

    return c
  }()

  static func string(from seconds: Int?) -> String? {
    guard let d = seconds, seconds != 0 else {
      return nil
    }

    if let cached = durations.object(forKey: d as NSNumber) {
      return cached as String
    }

    func done(_ str: String) -> String {
      durations.setObject(str as NSString, forKey: d as NSNumber)
      return str
    }

    if d < 3600 {
      let minutes = d / 60

      guard minutes >= 1 else {
        let s = d == 1 ? "second" : "seconds"
        return done("\(d) \(s)")
      }

      let m = minutes == 1 ? "minute" : "minutes"
      return done("\(minutes) \(m)")
    }

    let hours = d / 3600
    let h = hours == 1 ? "hour" : "hours"
    let minutes = (d % 3600) / 60

    guard minutes != 0 else {
      return done("\(hours) \(h)")
    }

    let m = minutes == 1 ? "minute" : "minutes"

    return done("\(hours) \(h) \(minutes) \(m)")
  }

}

// MARK: - Cells

extension StringRepository {

  static var feedCellSubtitles: NSCache<NSNumber, NSString> = {
    let c = NSCache<NSNumber, NSString>()

    c.countLimit = 1024

    return c
  }()

  static func feedCellSubtitle(for feed: Feed) -> String {
    let key = feed.hashValue as NSNumber

    guard let subtitle = feedCellSubtitles.object(forKey: key) else {
      var subtitle = ""

      if let author = feed.author {
        subtitle.append(author)
      } else {
        os_log("no author: %@", feed.title)
      }

      if let updated = feed.updated, updated != Date(timeIntervalSince1970: 0) {
        subtitle.append(", \(string(from: updated))")
      } else {
        os_log("embezzling updated: %@", feed.title)
      }

      feedCellSubtitles.setObject(subtitle as NSString, forKey: key)

      return subtitle
    }

    return subtitle as String
  }

  private static var episodeCellSubtitles: NSCache<NSNumber, NSString> = {
    let c = NSCache<NSNumber, NSString>()

    c.countLimit = 1024

    return c
  }()

  /// Returns a condensed subtitle for `entry` combining date, duration, and
  /// a short summary.
  ///
  /// Designed for table view cells, these are simple strings, cached for reuse.
  static func episodeCellSubtitle(for entry: Entry) -> String {
    let key = entry.hashValue as NSNumber

    if let subtitle = episodeCellSubtitles.object(forKey: key) {
      return subtitle as String
    }

    let updated = string(from: entry.updated)

    let snippet: String = {
      guard let subtitle = entry.subtitle ?? entry.summary else {
        return ""
      }

      // Keeping it short and simple, sweeping out HTML tags.

      return " – \(String(subtitle.prefix(140)))".replacingOccurrences(
        of: "<[^>]+>", with: "", options: .regularExpression)
    }()

    let times: String = {
      if let duration = string(from: entry.duration) {
        return "\(updated), \(duration)"
      }

      return updated
    }()

    let s = "\(times)\(snippet)"

    episodeCellSubtitles.setObject(s as NSString, forKey: key)

    return s
  }

}

// MARK: - User Messages

extension StringRepository {
  
  static func emptyFeed(titled: String? = nil) -> NSAttributedString {
    let bold: [NSAttributedString.Key : Any] = [
      .font: UIFont.preferredFont(forTextStyle: .headline)
    ]

    guard let title = titled else {
      return NSAttributedString(string: "This feed appears to be empty.")
    }
    
    let a = NSMutableAttributedString(string: "This feed – ")
    let b = NSAttributedString(string: "\(title)", attributes: bold)
    let c = NSAttributedString(string: " – appears to be empty.")
    
    a.append(b)
    a.append(c)
    
    return a
  }
  
  static func noEpisodeSelected() -> NSAttributedString {
    let headline: [NSAttributedString.Key : Any] = [
      .font: UIFont.preferredFont(forTextStyle: .title2)
    ]
    
    return NSMutableAttributedString(string:
      "No Episode Selected", attributes: headline)
  }

  /// Returns a message composed of `title` and `hint`.
  ///
  /// Always hint, suggesting a concrete action.
  private static func makeMessage(
    title: String,
    hint: String
  ) -> NSAttributedString {
    let headline: [NSAttributedString.Key : Any] = [
      .font: UIFont.preferredFont(forTextStyle: .largeTitle)
    ]
    
    let body: [NSAttributedString.Key : Any] = [
      .font: UIFont.preferredFont(forTextStyle: .body)
    ]
    
    let a = NSMutableAttributedString(string:"\(title)", attributes: headline)
    let b = NSAttributedString(string: "\n\n\(hint)", attributes: body)
    
    a.append(b)
    
    return a
  }
  
  static let emptyQueue: NSAttributedString = makeMessage(
    title: "No Episodes",
    hint: """
      Swipe down to refresh or search to explore. \
      Enqueued Episodes will show up here.
    """
  )

  static let loadingPodcast: NSAttributedString = makeMessage(
    title: "Loading",
    hint: "Please wait for your podcast to load."
  )

  static let loadingEpisodes: NSAttributedString = makeMessage(
    title: "Loading",
    hint: "Please wait for your episodes to load."
  )

  static let loadingQueue: NSAttributedString = makeMessage(
    title: "Loading",
    hint: "Please wait while your Queue is being synchronized."
  )
  
  static func noEpisode(with title: String) -> NSAttributedString {
    let bold: [NSAttributedString.Key : Any] = [
      .font: UIFont.preferredFont(forTextStyle: .headline)
    ]
    
    let a = NSMutableAttributedString(string: "Sorry, the episode – ")
    let b = NSAttributedString(string: "\(title)", attributes: bold)
    let c = NSAttributedString(string: " – cannot be displayed at the moment")
    
    a.append(b)
    a.append(c)
    
    return a
  }
  
  static func noResult(for term: String) -> NSAttributedString {
    let title = "No Results"
    let hint = "We didn’t find anything for “\(term)”. Try something else."

    return makeMessage(title: title, hint: hint)
  }
  
  static var serviceUnavailable: NSAttributedString {
    let title = "Service Unavailable"
    let hint = "Please try again later."

    return StringRepository.makeMessage(title: title, hint: hint)
  }

  static var offline: NSAttributedString {
    let title = "You’re Offline"
    let hint = "Turn off Airplane Mode or connect to Wi-Fi."
    
    return makeMessage(title: title, hint: hint)
  }
  
  static func unknown(_ error: Error) -> NSAttributedString {
    let title = "I’m Sorry"
    let hint = error.localizedDescription

    return makeMessage(title: title, hint: hint)
  }
  
  /// Returns an error message describing `error` or `nil` if the error can be
  /// ignored.
  ///
  /// Here’s the reasoning behind these messages.
  ///
  /// - A message is available and should be shown to the user.
  /// - No message is required, returning `nil`, the error can be ignored.
  /// - Unknown, an *unknown error* message is returned and might be displayed,
  /// but actually, handling is undefined.
  ///
  /// - Parameters:
  ///   - error: The error from which to produce a message.
  ///
  /// - Returns: An error message or `nil` if the error can be ignored.
  static func message(describing error: Error) -> NSAttributedString? {
    switch error {
    case FeedKitError.cancelledByUser:
      return nil
    case FeedKitError.serviceUnavailable:
      return serviceUnavailable
    case FeedKitError.invalidSearchTerm:
      return nil
    case FeedKitError.offline:
      return offline
    default:
      return unknown(error)
    }
  }
}
