//
//  strings.swift - get strings
//  Podest
//
//  Created by Michael Nisi on 07/08/16.
//  Copyright © 2016 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit
import os.log

private let log = OSLog.disabled

/// `StringRepository` provides static functions to make the more expensive
/// Strings.
class StringRepository {

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

  private static var entries: NSCache<NSString, NSAttributedString> = {
    let cache = NSCache<NSString, NSAttributedString>()
    cache.countLimit = 256
    return cache
  }()
  
  private struct EntryAttributes {
    let title1: [NSAttributedString.Key: Any] = [
      .font: UIFont.preferredFont(forTextStyle: .title1),
      .foregroundColor: UIColor.darkGray
    ]

    let caption1: [NSAttributedString.Key: Any] = [
      .font: UIFont.preferredFont(forTextStyle: .caption1),
      .foregroundColor: UIColor.lightGray
    ]
    
    let body: [NSAttributedString.Key: Any] = [
      .font: UIFont.preferredFont(forTextStyle: .body)
    ]
  }
  
  private static var entryAttributes = EntryAttributes()
  
  /// Returns an attributed String produced from an entry’s or feed’s summary.
  static func attribute(summary: String?) -> NSAttributedString {
    let html = HTMLAttributor()

    os_log("attributing: %@",
           log: log, type: .debug, String(describing: summary))

    let str = summary ?? "Unfortunately, I have no summary for this awesome content, at this time."
    
    do {
      let tree = try html.parse(str)
      return try html.attributedString(tree)
    } catch {
      os_log("parsing summary failed: %@", log: log, error as CVarArg)
      return NSAttributedString(string: str, attributes: entryAttributes.body)
    }
  }
  
  private static func footer(for entry: Entry) -> NSAttributedString {
    let duration = string(from: entry.duration) ?? ""
    let updated = string(from: entry.updated)
    let author = entry.author ?? ""
    let str = "\(duration)\n\(updated) by \(author)"
    
    return NSAttributedString(string: str, attributes: entryAttributes.caption1)
  }
  
  private func subtitle(for entry: Entry) -> NSAttributedString? {
    guard let feedTitle = entry.feedTitle else {
      return nil
    }
    
    let url = URL(string: "\(Podest.scheme)://\(Podest.domain)/feed?url=\(entry.feed)")
    let attributes: [NSAttributedString.Key : Any] = [
      .font: UIFont.preferredFont(forTextStyle: .headline),
      .link: url as AnyObject
    ]
    
    return NSAttributedString(string: feedTitle, attributes: attributes)
  }
  
  /// Synchronously, produces an attributed string for `entry`.
  static func string(for entry: Entry) -> NSAttributedString {
    if let cached = entries.object(forKey: entry.guid as NSString) {
      return cached
    }

    let attrString = NSMutableAttributedString(
      string: entry.title, attributes: entryAttributes.title1)
    
    func newline() {
      attrString.append(NSAttributedString(string: "\n\n"))
    }
    
    newline()
//    
//    if let attrSubtitle = subtitle(for: entry) {
//      attrString.append(attrSubtitle)
//      newline()
//    }
//    
    attrString.append(attribute(summary: entry.summary))
//    newline()
//    
//    attrString.append(footer(for: entry))

    entries.setObject(attrString, forKey: entry.guid as NSString)
    
    return attrString
  }
  
  static func purge() {
    durations.removeAllObjects()
    entries.removeAllObjects()
    episodeCellSubtitles.removeAllObjects()
  }
  
  // MARK: Feed Cell Subtitles
  
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
        subtitle.append("\n\(string(from: updated))")
      } else {
        os_log("embezzling updated: %@", feed.title)
      }
      
      feedCellSubtitles.setObject(subtitle as NSString, forKey: key)
      return subtitle
    }
    return subtitle as String
  }
  
  // MARK: Episode Cell Subtitles
  
  private static var episodeCellSubtitles: NSCache<NSNumber, NSString> = {
    let c = NSCache<NSNumber, NSString>()
    c.countLimit = 1024
    return c
  }()
  
  static func episodeCellSubtitle(for entry: Entry) -> String {
    let key = entry.hashValue as NSNumber
    guard let subtitle = episodeCellSubtitles.object(forKey: key) else {
      let updated = string(from: entry.updated)
      let subtitle: String = {
        if let duration = string(from: entry.duration) {
          return "\(updated), \(duration)"
        }
        return updated
      }()
      episodeCellSubtitles.setObject(subtitle as NSString, forKey: key)
      return subtitle
    }
    return subtitle as String
  }
  
}

// MARK: - User Messages

extension StringRepository {
  
  static func emptyFeed(titled: String?) -> NSAttributedString {
    let title = titled ?? ""
    
    let bold: [NSAttributedString.Key : Any] = [
      .font: UIFont.preferredFont(forTextStyle: .headline)
    ]
    
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
  
  static func emptyQueue() -> NSAttributedString {
    let title = "No Episodes"
    let hint = """
      Swipe down to refresh or search to explore. \
      Enqueued Episodes will show up here.
      """
    
    return StringRepository.makeMessage(title: title, hint: hint)
  }
  
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
    let bold: [NSAttributedString.Key : Any] = [
      .font: UIFont.preferredFont(forTextStyle: .headline)
    ]
    
    let a = NSMutableAttributedString(string: "Your search – ")
    let b = NSAttributedString(string: "\(term)", attributes: bold)
    let c = NSAttributedString(string: " – did not match anything.")

    a.append(b)
    a.append(c)

    return a
  }
  
  static var serviceUnavailable: NSAttributedString {
    let title = "Unavailable Service"
    let hint = "Sorry, try again later."

    return StringRepository.makeMessage(title: title, hint: hint)
  }

  static var offline: NSAttributedString {
    let title = "You’re offline"
    let hint = "Turn off Airplane Mode or connect to Wi-Fi."
    
    return StringRepository.makeMessage(title: title, hint: hint)
  }
  
  static func unknown(_ error: Error) -> NSAttributedString {
    let bold: [NSAttributedString.Key : Any] = [
      .font: UIFont.preferredFont(forTextStyle: .headline)
    ]
    
    let a = NSMutableAttributedString(string: "😓 Eww, an unknown error – ")
    let b = NSAttributedString(string: "\(error)", attributes: bold)
    let c = NSAttributedString(string: " – occurred.")
    
    a.append(b)
    a.append(c)
    
    return a
  }
  
  /// Returns an error message describing `error`, applying three conditions:
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
