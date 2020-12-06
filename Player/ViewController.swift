//
//  ViewController.swift
//  Player
//
//  Created by Michael Nisi on 31.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit
import Playback
import FeedKit

struct SomeImage: Imaginable {
  var image: String? = nil
  
  var title: String = ""
  
  var  iTunes: ITunesItem? = ITunesItem(
    url: "http://feeds.feedburner.com/RoderickOnTheLine",
    iTunesID: 471418144,
    img100: "https://is2-ssl.mzstatic.com/image/thumb/Podcasts114/v4/30/fe/c5/30fec595-c772-f80e-289b-4974844224b4/mza_4773085836270850850.jpg/100x100bb.jp",
    img30: "https://is2-ssl.mzstatic.com/image/thumb/Podcasts114/v4/30/fe/c5/30fec595-c772-f80e-289b-4974844224b4/mza_4773085836270850850.jpg/30x30bb.jpg",
    img60: "https://is2-ssl.mzstatic.com/image/thumb/Podcasts114/v4/30/fe/c5/30fec595-c772-f80e-289b-4974844224b4/mza_4773085836270850850.jpg/60x60bb.jpg",
    img600: "https://is2-ssl.mzstatic.com/image/thumb/Podcasts114/v4/30/fe/c5/30fec595-c772-f80e-289b-4974844224b4/mza_4773085836270850850.jpg/600x600bb.jpg"
  )
}

class ViewController: UIViewController {
  
  @IBAction func tapped(_ sender: UITapGestureRecognizer) {
    guard let vc = storyboard?.instantiateViewController(
      withIdentifier: "PlayerV3ID") as? PlayerV3ViewController else {
      fatalError("missing view controller")
    }
  
    present(vc, animated: true)
    
    vc.configure(
      title: "#86 Man of the People",
      subtitle: "Reply All",
      imaginable: SomeImage()
    )
  }
}

