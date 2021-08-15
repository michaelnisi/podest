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

import UIKit
import Foundation

class PlaySwitch: UIControl {
  
  // Using three image views, because during animation we may display them
  // simultaneously .
  private var offImageView = UIImageView()
  private var onImageView = UIImageView()
  private var backgroundImageView = UIImageView()
  
  @IBInspectable var offImage: UIImage! {
    didSet {
      offImageView.image = offImage
    }
  }
  
  @IBInspectable var onImage: UIImage! {
    didSet {
      onImageView.image = onImage
    }
  }
  
  @IBInspectable var backgroundImage: UIImage! {
    didSet {
      backgroundImageView.image = backgroundImage
    }
  }
  
  var isOn: Bool = false {
    didSet {
      onImageView.isHidden = !isOn
      offImageView.isHidden = isOn
    }
  }
  
  private var prev: UIImageView {
    return isOn ? offImageView : onImageView
  }
  
  private var current: UIImageView {
    return isOn ? onImageView : offImageView
  }
  
  private func resetImages() {
    current.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    
    UIView.animate(withDuration: 0.2, animations: { [weak self] in
      self?.current.transform = CGAffineTransform(scaleX: 1, y: 1)
      
      self?.backgroundImageView.alpha = 0
      self?.backgroundImageView.transform = CGAffineTransform(scaleX: 1, y: 1)
    }) { [weak self] success in
      self?.backgroundImageView.isHidden = true
      
      self?.prev.isHidden = true
      self?.prev.transform = CGAffineTransform(scaleX: 1, y: 1)
    }
  }

  override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    backgroundImageView.isHidden = false
    backgroundImageView.alpha = 0
    backgroundImageView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
    
    current.transform = CGAffineTransform(scaleX: 1, y: 1)
    current.isHidden = false
    
    UIView.animate(withDuration: 0.3) { [weak self] in
      self?.current.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
      
      self?.backgroundImageView.alpha = 1
      self?.backgroundImageView.transform = CGAffineTransform(scaleX: 1, y: 1)
    }

    return super.beginTracking(touch, with: event)
  }
  
  override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
    super.endTracking(touch, with: event)
    
    isOn = !isOn
    
    sendActions(for: .valueChanged)
    resetImages()
    
    isCancelled = false
  }
  
  override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    guard hitTest(touch.location(in: self), with: event) != nil else {
      resetImages()
      
      isCancelled = true
      
      return false
    }
    
    isCancelled = false
    
    return true
  }

  /// Informally flagging cancellations, can be reset by users.
  var isCancelled: Bool = false

  override func cancelTracking(with event: UIEvent?) {
    super.cancelTracking(with: event)
    resetImages()
    
    isCancelled = true
  }
  
  private func addConstraints(to imageView: UIImageView) {
    imageView.isUserInteractionEnabled = false
    imageView.translatesAutoresizingMaskIntoConstraints = false
    
    imageView.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
    imageView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    imageView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    imageView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
  }
  
  private func commonInit() {
    addSubview(backgroundImageView)
    addSubview(offImageView)
    addSubview(onImageView)
    
    addConstraints(to: backgroundImageView)
    addConstraints(to: offImageView)
    addConstraints(to: onImageView)

    backgroundImageView.isHidden = true
    onImageView.isHidden = true
    offImageView.isHidden = false
    
    if #available(iOS 13.0, *) {
      backgroundImageView.tintColor = .tertiarySystemGroupedBackground
    } else {
      backgroundImageView.tintColor = .gray
    }
    
    self.sendSubviewToBack(backgroundImageView)
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }
}
