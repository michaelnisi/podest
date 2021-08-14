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
import UIKit
import os.log
import Ola
import Podcasts

extension QueueViewController: StoreAccessDelegate {
  
  func reach() -> Bool {
    let host = "https://itunes.apple.com"
//    let host = "https://sandbox.itunes.apple.com"
    let log = OSLog(subsystem: "ink.codes.podest", category: "store")
    guard let probe = self.probe ?? Ola(host: host, log: log) else {
      os_log("creating reachability probe failed", log: log, type: .error)
      return true
    }
    
    switch probe.reach() {
    case .cellular, .reachable:
      return true
    case .unknown:
      let ok = probe.activate { [weak self] status in
        switch status {
        case .cellular, .reachable:
          self?.probe = nil
          Podcasts.store.online()
        case .unknown:
          break
        }
      }
      
      if ok {
        self.probe = probe
      } else {
        os_log("installing reachability callback failed", log: log, type: .error)
      }
      
      return false
    }
  }
  
  func store(_ store: Shopping, isAccessible: Bool) {
    DispatchQueue.main.async { [weak self] in
      self?.isStoreAccessible = isAccessible
    }
  }
  
  func store(_ store: Shopping, isExpired: Bool) {
    guard isExpired else {
      return
    }
    
    DispatchQueue.main.async { [weak self] in
      let alert = UIAlertController(
        title: "Free Trial Expired",
        message: "Let’s get it.",
        preferredStyle: .alert
      )
      
      let ok = UIAlertAction(title: "In-App Purchases", style: .default) { _ in
        alert.dismiss(animated: true)
        self?.navigationDelegate?.showStore()
      }
      
      alert.addAction(ok)
      self?.present(alert, animated: true, completion: nil)
      Podcasts.player.pause()
      Podest.gateway.cancelAlBGTaskRequests()
    }
  }
}
