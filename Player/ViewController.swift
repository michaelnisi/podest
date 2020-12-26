//
//  ViewController.swift
//  Player
//
//  Created by Michael Nisi on 31.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit

class ViewController: UIViewController {
  
  @IBAction func tapped(_ sender: UITapGestureRecognizer) {
    guard let vc = storyboard?.instantiateViewController(
      withIdentifier: "PlayerV3ID") as? PlayerV3ViewController else {
      fatalError("missing view controller")
    }

    vc.entry = entry
    
    present(vc, animated: true)
  }
  
  private var entry: Entry {
    guard let url = Bundle.main.url(forResource: "entry", withExtension: "json") else {
      fatalError("data not found")
    }
    
    let data = try! Data(contentsOf: url)
    
    return try! JSONDecoder().decode(Entry.self, from: data)
  }
}

