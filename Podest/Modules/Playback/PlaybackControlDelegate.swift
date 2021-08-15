//===----------------------------------------------------------------------===//
//
// This source file is part of the Podest open source project
//
// Copyright (c) 2021 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/podest/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

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
