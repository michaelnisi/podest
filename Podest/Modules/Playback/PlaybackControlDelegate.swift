//
//  PlaybackControlDelegate.swift
//  Podest
//
//  Created by Michael Nisi on 21.03.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import Foundation
import FeedKit
import UIKit
import os.log
import InsetPresentation

import Podcasts

private let log = OSLog(subsystem: "ink.codes.podest", category: "Playback")

/// Handles playback view relevant playback events. We can have few of these,
/// mini-player, player, now playing, etc.
protocol PlaybackControlDelegate {
  var entry: Entry? { get set }
  var isPlaying: Bool { get set }
  
  var isForwardable: Bool { get set }
  var isBackwardable: Bool { get set }
}
