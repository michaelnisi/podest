//
//  ActionSheetPresenting.swift
//  Podest
//
//  Created by Michael Nisi on 24.04.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import UIKit

/// Useful default action sheet things for view controllers.
protocol ActionSheetPresenting {}

extension ActionSheetPresenting where Self: UIViewController {
  
  static func makeCancelAction(
    handler: ((UIAlertAction) -> Void)? = nil
    ) -> UIAlertAction {
    let t = NSLocalizedString("Cancel", comment: "Cancel by default")
    
    return UIAlertAction(title: t, style: .cancel, handler: handler)
  }
  
  static func makeOpenLinkAction(string: String?) -> UIAlertAction? {
    guard let link = string, let linkURL = URL(string: link) else {
      return nil
    }
    
    let t =  NSLocalizedString("Open Link", comment: "Open browser link")
    
    return UIAlertAction(title: t, style: .default) { action in
      UIApplication.shared.open(linkURL)
    }
  }
  
  static func makeCopyFeedURLAction(string: String) -> UIAlertAction {
    let t = NSLocalizedString("Copy Feed URL", comment: "Copy non-browser link")
    
    return UIAlertAction(title: t, style: .default) { action in
      UIPasteboard.general.string = string
    }
  }
}
