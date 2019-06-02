//
//  PlayerV2ViewController.swift
//  Player
//
//  Created by Michael Nisi on 10.05.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit
import os.log

private let log = OSLog(subsystem: "ink.codes.podest", category: "player")

// MARK: - DoneButton

/// A simple button floating in the top left corner for closing things.
class DoneButton {
  private let view: UIView
  
  var doneBlock: (() -> Void)?
  
  private static func makeConstraints(view: UIView, subview: UIView) -> [NSLayoutConstraint] {
    return [
      subview.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
      subview.leftAnchor.constraint(equalTo: view.layoutMarginsGuide.leftAnchor)
    ]
  }
  
  @objc func touchUpInside() {
    doneBlock?()
  }
  
  private func install(button: UIButton) {
    button.addTarget(self, action: #selector(touchUpInside), for: .touchUpInside)
  }
  
  init(view: UIView) {
    self.view = view
    let img = UIImage(named: "Done")
    let frame = CGRect(x: 0, y: 0, width: 56, height: 56)
    let button = UIButton(frame: frame)
    
    button.setImage(img, for: .normal)
    
    button.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(button)
    
    let constraints = DoneButton.makeConstraints(view: view, subview: button)
    for c in constraints { c.isActive = true }
    
    install(button: button)
  }
}

// MARK: - PlayerV2ViewController

class PlayerV2ViewController: UICollectionViewController {
  
  let dataSource = PlayerDataSource()
  var doneButton: DoneButton!
  var entryChangedBlock: ((Entry?) -> Void)?
  var statusBarHidden = false
  
  deinit {
    os_log("** deinit", log: log, type: .debug)
  }
}

// MARK: - UICollectionViewDelegate

extension PlayerV2ViewController {
  
  /// Installs `cell` and returns its managing view controller.
  private func install(cell: UICollectionViewCell) -> UIViewController? {
    switch cell {
    case let hosted as MoreCell:
      let sid: String = {
        switch hosted.type! {
        case .chapters:
          return "ChaptersID"
        case .queue:
          return "QueueID"
        }
      }()
      
      os_log("finding view controller", log: log, type: .debug)
      
      guard hosted.container == nil else {
        os_log("returning cached view controller", log: log, type: .debug)
        return hosted.container
      }
      
      guard let vc = storyboard?.instantiateViewController(
        withIdentifier: sid) else {
        fatalError("missing view controller in storyboard")
      }
      
      os_log("instantiated view controller", log: log, type: .debug)
      
      hosted.container = vc
      
      return vc

    default:
      return nil
    }
  }
  
  override func collectionView(
    _ collectionView: UICollectionView, 
    willDisplay cell: UICollectionViewCell, 
    forItemAt indexPath: IndexPath) {
    guard let vc = install(cell: cell) else {
      return
    }
    
    addChild(vc)

    vc.view.frame = cell.contentView.frame
    cell.contentView.addSubview(vc.view)
    
    vc.didMove(toParent: self)
  }
  
  override func collectionView(
    _ collectionView: UICollectionView, 
    didEndDisplaying cell: UICollectionViewCell, 
    forItemAt indexPath: IndexPath) {
    switch cell {
    case let hosted as MoreCell:
      hosted.container?.willMove(toParent: nil)
      hosted.container?.removeFromParent()
    default:
      break
    }
  }
}

// MARK: - UIViewController

extension PlayerV2ViewController {
  
  override var prefersStatusBarHidden: Bool { 
    return statusBarHidden 
  }
  
  override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
    return .slide
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    dataSource.registerCells(collectionView: collectionView)
    
    collectionView.dataSource = dataSource
    collectionView.collectionViewLayout = TwoPlusLayout()

    toolbarItems = makeToolbarItems(rate: 1.5) 
    
    doneButton = DoneButton(view: view)
    doneButton.doneBlock = { [weak self] in
      self?.dismiss(animated: true)
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    UIView.animate(withDuration: 0.25) {
      self.statusBarHidden = true
      
      self.setNeedsStatusBarAppearanceUpdate()
    }
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    statusBarHidden = false
    
    self.setNeedsStatusBarAppearanceUpdate()
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    for child in children {
      child.willMove(toParent: nil)
      child.removeFromParent()
    }
  }
}

// MARK: - Toolbar

extension PlayerV2ViewController {
  
  @objc func nop() {}
  
  private func makeToolbarItems(rate: Double = 1) -> [UIBarButtonItem] {
    return [
      UIBarButtonItem(
        title: "\(rate) ×", 
        style: .plain, 
        target: self, 
        action: #selector(nop)
      ),
      UIBarButtonItem(
        barButtonSystemItem: .flexibleSpace, 
        target: nil, 
        action: nil
      ),
      UIBarButtonItem(
        image: UIImage(named: "Sleep"), 
        style: .plain, 
        target: self, 
        action: #selector(nop)
      ),
      UIBarButtonItem(
        barButtonSystemItem: .flexibleSpace, 
        target: nil, 
        action: nil
      ),
      UIBarButtonItem(
        image: UIImage(named: "AirPlay-Glyph-Audio"), 
        style: .plain, 
        target: self, 
        action: #selector(nop)
      ),
      UIBarButtonItem(
        barButtonSystemItem: .flexibleSpace, 
        target: nil, 
        action: nil
      ),
      UIBarButtonItem(
        barButtonSystemItem: .action, 
        target: self, 
        action: #selector(nop)
      )
    ]
  }
}
