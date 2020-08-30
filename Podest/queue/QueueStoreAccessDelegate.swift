//
//  QueueStoreAccessDelegate.swift
//  Podest
//
//  Created by Michael Nisi on 21.04.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import UIKit
import os.log
import Ola

extension QueueViewController: StoreAccessDelegate {
  
  func reach() -> Bool {
    let host = "https://itunes.apple.com"
    // "https://sandbox.itunes.apple.com"
    let log = OSLog.disabled
    
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
          Podest.store.online()
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
      self?.navigationDelegate?.pause()
      Podest.gateway.cancel()
    }
  }
}
