//
//  EpisodeViewController.swift
//  Podest
//
//  Created by Michael on 2/1/16.
//  Copyright © 2016 Michael Nisi. All rights reserved.
//

import UIKit
import FeedKit
import os.log
import Foundation

private let log = OSLog.disabled

final class EpisodeViewController: UIViewController, EntryProvider, Navigator {

  @IBOutlet var avatar: UIImageView!
  @IBOutlet var feedButton: UIButton!
  @IBOutlet var updatedLabel: UILabel!
  @IBOutlet var durationLabel: UILabel!
  @IBOutlet var content: UITextView!
  @IBOutlet var scrollView: UIScrollView!

  /// The locator of the current entry or `nil`.
  ///
  /// Set before `viewWillAppear(_:)`, it’s used to fetch the matching entry.
  var locator: EntryLocator?

  /// A changed flag for efficiency.
  private var entryChanged = false

  var entry: Entry? {
    didSet {
      entryChanged = entry != oldValue

      if let e = entry {
        locator = EntryLocator(entry: e)
      } else {
        locator = nil
      }

      guard entryChanged, viewIfLoaded != nil else {
        return
      }

      loadImageIfNeeded()
      updateIsEnqueued()
      configureView()

      entryChanged = false
    }
  }

  /// `true` if this episode is in the queue.
  var isEnqueued: Bool = false {
    didSet {
      guard navigationItem.rightBarButtonItems == nil ||
        isEnqueued != oldValue else {
        return
      }

      configureNavigationItem()
    }
  }

  /// Returns `true` if neither entry nor locator have been set.
  var isEmpty: Bool {
    return entry == nil && locator == nil
  }

  /// The **required** navigation delegate.
  var navigationDelegate: ViewControllers?

  /// Enables us to cancel the fetching entries operation.
  weak private var fetchingEntries: Operation?

  @objc func selectFeed() {
    guard let url = entry?.feed else {
      fatalError("cannot select undefined feed")
    }
    navigationDelegate?.openFeed(url: url, animated: true)
  }

  /// The size of the currently loaded image.
  private var imageLoaded: CGSize = .zero

  /// Restored content offset from state preservation.
  private var restoredContentOffset: CGPoint?

  /// Restore frame size from state preservation.
  private var restoredFrameSize: CGSize?
  
  private var listContext: AnyObject?
}

// MARK: - Unsubscribing

extension EpisodeViewController: Unsubscribing {}

// MARK: - UIViewController

extension EpisodeViewController {

  override func viewDidLoad() {
    resetView()

    feedButton.titleLabel?.numberOfLines = 0

    feedButton.addTarget(
      self, action: #selector(selectFeed), for: .touchUpInside)

    if let label = feedButton.titleLabel {
      label.rightAnchor.constraint(equalTo:
        feedButton.rightAnchor).isActive = true
    }

    content.delegate = self
    navigationItem.largeTitleDisplayMode = .never

    super.viewDidLoad()
  }
  
  @available(iOS 13.0, *)
  private func installFeedLongPress() {
    (listContext as? ListContextMenuInteraction)?.invalidate()
    
    guard let feedButton = feedButton, let entry = entry else {
      return
    }
    
    listContext = ListContextMenuInteraction(view: feedButton, entry: entry, viewController: self)
    (listContext as? ListContextMenuInteraction)?.install()
  }

  override func viewWillAppear(_ animated: Bool) {
    defer {
      super.viewWillAppear(animated)
    }

    if entryChanged {
      loadImageIfNeeded()
      configureView()
      updateIsEnqueued()
      
      if #available(iOS 13.0, *) { 
        installFeedLongPress()
      }
      
      entryChanged = false
    }

    guard let locator = self.locator, entry == nil else {
      return
    }

    fetchingEntries?.cancel()

    var acc = [Entry]()

    fetchingEntries = Podest.browser.entries(
      [locator.including], entriesBlock: { error, entries in
        if let er = error {
          os_log("entry block error: %{public}@", log: log, type: .error,
                 String(describing: er))
        }

        acc.append(contentsOf: entries)
    }) { [weak self] error in
      guard error == nil else {
        if let msg = StringRepository.message(describing: error!) {
          DispatchQueue.main.async {
            self?.showMessage(msg)
          }
        }
        return
      }

      guard let e = acc.first else {
        let title = self?.title ?? ""
        let message = StringRepository.noEpisode(with: title)
        DispatchQueue.main.async { [weak self] in
          self?.showMessage(message)
        }
        return
      }

      DispatchQueue.main.async {
        self?.entry = e
      }
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if isEmpty {
      showMessage(StringRepository.noEpisodeSelected())
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)

    fetchingEntries?.cancel()
    content?.isSelectable = false
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    // Passing animations to prevent redundant loading.

    DispatchQueue.main.async { [weak self] in
      self?.loadImageIfNeeded()
    }
  }
}

// MARK: - Responding to a Change in the Interface Environment

extension EpisodeViewController {

  override func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)

    content?.resignFirstResponder()
  }
}

// MARK: - State Preservation and Restoration

extension EpisodeViewController {

  override func encodeRestorableState(with coder: NSCoder) {
    locator?.encode(with: coder)

    super.encodeRestorableState(with: coder)
  }

  override func decodeRestorableState(with coder: NSCoder) {
    locator = EntryLocator(coder: coder)

    super.decodeRestorableState(with: coder)
  }

}

// MARK: - Updating View, Image, and Navigation Item

extension EpisodeViewController {

  private func showMessage(_ msg: NSAttributedString) {
    os_log("episode: showing message", log: log, type: .info)

    let messageView = MessageView.make()

    messageView.frame = view.frame
    view.addSubview(messageView)

    messageView.attributedText = msg
  }

  /// Updates the `isEnqueued` property using `enqueued` or the user queue.
  func updateIsEnqueued(using enqueued: Set<EntryGUID>? = nil) -> Void {
    os_log("updating is enqueued: %@", log: log, type: .info, self)

    guard let e = entry else {
      navigationItem.rightBarButtonItems = nil
      return
    }

    guard let guids = enqueued else {
      if Podest.userQueue.isEmpty, Podest.userLibrary.hasNoSubscriptions {
        // At launch, during state restoration, the user library might not be
        // completely synchronized yet, so we sync and wait before configuring
        // the navigation item. We are misusing isEmpty to check that.

        Podest.userLibrary.synchronize { [weak self] _, guids, error in
          if let er = error {
            switch er {
            case QueueingError.outOfSync(let queue, let guids):
              if queue == 0, guids != 0 {
                os_log("queue not populated", log: log, type: .info)
              } else {
                os_log("** out of sync: ( queue: %i, guids: %i )",
                       log: log, type: .info, queue, guids)
              }
            default:
              fatalError("probably a database error: \(er)")
            }
          }

          DispatchQueue.main.async {
            self?.isEnqueued = guids?.contains(e.guid) ?? false
          }
        }
      } else {
        isEnqueued = Podest.userQueue.contains(entry: e)
      }
      return
    }

    isEnqueued = guids.contains(e.guid)
  }

  /// Loads hero in suitable size. NOP if the image size hasn’t changed since 
  /// the last time the image has been loaded.
  ///
  /// Here’s the thing about these images, once we have an entry, we can assume
  /// that we already have the image URLs because an entry cannot exist without
  /// its parent feed, which provides the image URLs. Orphans are undefined and
  /// thus considered programming errors. To load the correct image though, we
  /// have to know its size, depending on the layout. For example, larger sizes
  /// on iPad.
  private func loadImageIfNeeded() {
    guard let entry = self.entry,
      let size = avatar.image?.size,
      (size.width > imageLoaded.width || size.height > imageLoaded.height) else {
      return
    }

    Podest.images.loadImage(
      representing: entry,
      into: avatar,
      options: FKImageLoadingOptions(quality: .high)
    )

    imageLoaded = size
  }

  private func resetView() {
    UIView.performWithoutAnimation {
      feedButton.setTitle(nil, for: .normal)
    }

    updatedLabel.text  = nil
    durationLabel.text = nil
    content.attributedText = nil
  }

  private func configureView() -> Void {
    assert(viewIfLoaded != nil)

    guard let entry = self.entry else {
      return resetView()
    }

    UIView.performWithoutAnimation {
      feedButton.setTitle(entry.feedTitle, for: .normal)
    }

    updatedLabel.text = StringRepository.string(from: entry.updated)

    if let duration = entry.duration,
      let text = StringRepository.string(from: duration) {
      durationLabel.text = text
    } else {
      durationLabel.isHidden = true
    }

    DispatchQueue.global(qos: .userInteractive).async { [weak self] in
      let attributedText = StringRepository.makeSummaryWithHeadline(entry: entry)

      DispatchQueue.main.async {
        self?.content?.attributedText = attributedText

        if let offset = self?.restoredContentOffset,
          self?.restoredFrameSize == self?.scrollView.frame.size {
          self?.scrollView?.contentOffset = offset
          self?.restoredContentOffset = nil
        }
      }
    }
  }

}

// MARK: - UIResponder

extension EpisodeViewController {

  @discardableResult override func resignFirstResponder() -> Bool {
    content?.resignFirstResponder()
    return super.resignFirstResponder()
  }

}

// MARK: - Action Sheets

extension EpisodeViewController: ActionSheetPresenting {}

// MARK: - Removing Action Sheet

extension EpisodeViewController {

  private static func makeDequeueAction(
    entry: Entry, viewController: EpisodeViewController) -> UIAlertAction {
    let t = NSLocalizedString("Delete", comment: "Delete episode from queue")

    return UIAlertAction(title: t, style: .destructive) {
      [weak viewController] action in
      Podest.userQueue.dequeue(entry: entry) { dequeued, error in
        if let er = error {
          os_log("dequeue error: %{public}@",
                 log: log, type: .error, er as CVarArg)
        }

        if dequeued.isEmpty {
          os_log("** not dequeued", log: log)
        }

        DispatchQueue.main.async {
          viewController?.isEnqueued = !dequeued.contains(entry)
        }
      }
    }
  }

  private static func makeRemoveActions(
    entry: Entry, viewController: EpisodeViewController) -> [UIAlertAction] {
    var actions =  [UIAlertAction]()

    let dequeue = makeDequeueAction(entry: entry, viewController: viewController)
    let cancel = makeCancelAction()

    actions.append(dequeue)
    actions.append(cancel)

    return actions
  }

  private func makeRemoveController() -> UIAlertController {
    guard let entry = self.entry else {
      fatalError("entry expected")
    }

    let alert = UIAlertController(
      title: entry.title, message: nil, preferredStyle: .actionSheet
    )

    let actions = EpisodeViewController.makeRemoveActions(
      entry: entry, viewController: self)

    for action in actions {
      alert.addAction(action)
    }

    return alert
  }

}

// MARK: - Sharing Action Sheet

extension EpisodeViewController {

  private static func makeMoreActions(entry: Entry) -> [UIAlertAction] {
    var actions = [UIAlertAction]()

    if let openLink = makeOpenLinkAction(string: entry.link) {
      actions.append(openLink)
    }

    let copyFeedURL = makeCopyFeedURLAction(string: entry.feed)
    actions.append(copyFeedURL)

    let cancel = makeCancelAction()
    actions.append(cancel)

    return actions
  }

  private func makeMoreController() -> UIAlertController {
    guard let entry = self.entry else {
      fatalError("entry expected")
    }

    let alert = UIAlertController(
      title: nil, message: nil, preferredStyle: .actionSheet
    )

    let actions = EpisodeViewController.makeMoreActions(entry: entry)

    for action in actions {
      alert.addAction(action)
    }

    return alert
  }

}

// MARK: - Configure Navigation Item

extension EpisodeViewController {

  @objc func onPlay(_ sender: Any) {
    navigationDelegate?.play(entry!)
  }

  private func makePlayButton(for entry: Entry) -> UIBarButtonItem {
    // Deliberately not changing the play button, just ignoring another tap for
    // now. Switching between .play and .pause felt too distracting. Accent the
    // player.
    return UIBarButtonItem(
      barButtonSystemItem: .play, target: self, action: #selector(onPlay))
  }

  @objc func onRemove(_ sender: UIBarButtonItem) {
    let alert = makeRemoveController()
    if let presenter = alert.popoverPresentationController {
      presenter.barButtonItem = sender
    }

    self.present(alert, animated: true, completion: nil)
  }

  @objc func onAdd(_ sender: UIBarButtonItem) {
    guard  let entry = self.entry else {
      fatalError("entry expected")
    }

    sender.isEnabled = false

    Podest.userQueue.enqueue(entries: [entry], belonging: .user) {
      [weak self] enqueued, error in
      if let er = error {
        os_log("enqueue error: %{public}@", type: .error, er as CVarArg)
      }

      if enqueued.isEmpty {
        os_log("** not enqueued", log: log)
      }

      DispatchQueue.main.async {
        sender.isEnabled = true
        self?.isEnqueued = enqueued.contains(entry)
      }
    }
  }

  private func makeQueueButton(for entry: Entry) -> UIBarButtonItem {
    if isEnqueued {
      return UIBarButtonItem(
        barButtonSystemItem: .trash, target: self, action: #selector(onRemove))
    } else {
      return UIBarButtonItem(
        barButtonSystemItem: .add, target: self, action: #selector(onAdd))
    }
  }

  @objc func onMore(_ sender: UIBarButtonItem) {
    let alert = makeMoreController()
    if let presenter = alert.popoverPresentationController {
      presenter.barButtonItem = sender
    }
    self.present(alert, animated: true, completion: nil)
  }

  private func makeMoreButton() -> UIBarButtonItem {
    return UIBarButtonItem(
      barButtonSystemItem: .action, target: self, action: #selector(onMore)
    )
  }

  private func configureNavigationItem() {
    guard let entry = self.entry else {
      return navigationItem.rightBarButtonItems = nil
    }

    let items = [
      makePlayButton(for: entry),
      makeMoreButton(),
      makeQueueButton(for: entry)
    ]
    
    UIView.performWithoutAnimation {
      navigationItem.rightBarButtonItems = items
    }
  }

}

// MARK: - UITextViewDelegate

extension EpisodeViewController: UITextViewDelegate {

  func textView(
    _ textView: UITextView,
    shouldInteractWith URL: URL,
    in characterRange: NSRange
  ) -> Bool {
    guard URL.scheme == Podest.scheme else {
      return true
    }
    return !(navigationDelegate?.open(url: URL))!
  }

}
