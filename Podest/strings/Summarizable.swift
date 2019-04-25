//
//  Summarizable.swift
//  Podest
//
//  Created by Michael Nisi on 24.04.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import FeedKit

/// Types that conform to the `Summarizable` protocol are typically entities
/// that can be displayed as a single text paragraph.
protocol Summarizable: Hashable {
  var summary: String? { get }
  var title: String { get }
  var author: String? { get }
  var guid: String { get }
}

// MARK: - Extending Core Types

extension Entry: Summarizable {}

extension Feed: Summarizable {
  
  var guid: String {
    return self.url // Anything unique for NSCache.
  }
}

