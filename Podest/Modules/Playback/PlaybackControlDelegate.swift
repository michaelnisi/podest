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

import FeedKit

/// Handles playback view relevant playback events.
protocol PlaybackControlDelegate {
  var entry: Entry? { get set }
  var isPlaying: Bool { get set }
  var isForwardable: Bool { get set }
  var isBackwardable: Bool { get set }
}
