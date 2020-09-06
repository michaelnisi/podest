//
//  stubs.swift
//  Podest
//
//  Created by Michael Nisi on 31.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import Foundation
import FeedKit

// While we are working on the new user interface.
extension PlayerV3ViewController: EntryPlayer {

  var navigationDelegate: ViewControllers? {
    get {
      return nil
    }
    set {

    }
  }

  var entry: Entry? {
    get {
      return nil
    }
    set {
      dispatchPrecondition(condition: .onQueue(.main))
      
    }
  }

  var isPlaying: Bool {
    get {
      return false
    }
    set {

    }
  }

  var isForwardable: Bool {
    get {
      return false
    }
    set {

    }
  }

  var isBackwardable: Bool {
    get {
      return false
    }
    set {

    }
  }
}


/// While we are working on the new user interface.
extension PlayerV2ViewController: EntryPlayer {
  
  var navigationDelegate: ViewControllers? {
    get {
      return nil
    }
    set {
      
    }
  }
  
  var entry: Entry? {
    get {
      return nil
    }
    set {
      dispatchPrecondition(condition: .onQueue(.main))
      entryChangedBlock?(newValue)
    }
  }
  
  var isPlaying: Bool {
    get {
      return false
    }
    set {
      
    }
  }
  
  var isForwardable: Bool {
    get {
      return false
    }
    set {
      
    }
  }
  
  var isBackwardable: Bool {
    get {
      return false
    }
    set {
      
    }
  }
}
