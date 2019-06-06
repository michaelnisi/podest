//
//  ViewController.swift
//  Player
//
//  Created by Michael Nisi on 31.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
  
  @IBAction func tapped(_ sender: UITapGestureRecognizer) {
    guard let vc = storyboard?.instantiateViewController(
      withIdentifier: "PlayerID") else {
      fatalError("missing view controller")
    }
  
    present(vc, animated: true)
  }
}

