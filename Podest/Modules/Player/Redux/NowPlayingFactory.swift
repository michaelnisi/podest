//
//  Factory.swift
//  Podest
//
//  Created by Michael Nisi on 23.05.21.
//  Copyright © 2021 Michael Nisi. All rights reserved.
//

import UIKit
import Playback
import Epic
import FeedKit
import Combine
import SwiftUI

// MARK: - Images

struct NowPlayingFactory {
  var fallback: UIImage {
    UIImage()
  }
  
  func loadImage(representing entry: Entry, at size: CGSize) -> AnyPublisher<UIImage, Never> {
    ImageRepository.shared.loadImage(representing: entry, at: size)
      .replaceError(with: fallback)
      .eraseToAnyPublisher()
  }
}

// MARK: - Full

extension NowPlayingFactory {
  func makePlayerItem(entry: Entry, image: UIImage) -> Epic.Player.Item {
    Player.Item(
      title: entry.title,
      subtitle: entry.feedTitle ?? "Some Podcast",
      colors: Colors(image: image),
      image: Image(uiImage: image)
    )
  }
  
  func transformListening(entry: Entry, asset: AssetState) -> AnyPublisher<NowPlaying.State, Never> {
    loadImage(representing: entry, at: CGSize(width: 600, height: 600))
      .map { image in
        let item = self.makePlayerItem(entry: entry, image: image)
        let player = Epic.Player(
          item: item,
          isPlaying: asset.isPlaying,
          isForwardable: true,
          isBackwardable: true,
          trackTime: asset.time
        )
        
        return .full(entry, player)
      }
      .eraseToAnyPublisher()
  }
}

// MARK: - Mini

extension NowPlayingFactory {
  func makeMiniPlayerItem(entry: Entry) -> MiniPlayer.Item {
    MiniPlayer.Item(title: entry.title)
  }
}

// MARK: - Video

extension NowPlaying {

}
