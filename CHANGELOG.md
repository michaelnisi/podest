## 9.2 (2020-03-31)

This new version brings context menus for accessing most functionality directly from onscreen items. Additionally, the player is presented in default iOS style now.

## 9.1 (2019-10-26)

Resolves an issue where the Queue would not be updating reliably.

## 9.0 (2019-10-15)

This version is optimized for iOS 13 and supports Dark Mode.

Additional improvements focus around the Queue:

* Swipe right to play
* Context menus for quick episode actions
* Large title and improved pull-to-refresh

## 8.5 (2019-08-12)

Less memory use, more effective CPU utilization, and lighter energy impact.

## 8.4 (2019-07-31)

Smoother transitions through better image caching.

## 8.3 (2019-07-23)

Search result image sizes have been fixed.

Improved video playback integration, animating the mini-player when skipping between audio and video, and allowing seemless skipping from video to video using Now Playing on Apple Watch.

No more flickering of the mini-player play button.

## 8.2 (2019-07-15)

Good news, everyone! Two long-standing issues have been resolved.

Match against full episode data (title, subtitle, summary, author) for search suggestions, previously only the summary was scanned.

Watching a video on your phone in landscape no longer affects the list header.

## 8.1 (2019-07-05)

In preparation for iOS 13 this fall, these changes adjust layout timing, improve performance, and install scaffolding for a new player user interface, which should also be dropping this fall.

Improved multitasking on iPad: the list header adjusts according to layout and the player animation maintains the aspect ratio of the episode image.

Higher resolution images and more effective loading and processing.

The mini-player chrome got a gray border at its top edge.

The Queue now indicates which episodes have not been played yet.

Improved performance and effectiveness: using less threads and disabling HTTP pipelining.

Following bugs have been fixed along the way:

List loading displays correct error message when offline, previously this had been incorrectly reported as service unavailable.

In some use cases, during search, the mini-player obscured lists. This has been fixed.

After an episode has been played to its end, Control Center is updated correctly and, played the next time, the episode will resume at the beginning.

Settings.app displays correct version and status.

## 8 (2019-04-25)

This version, the first using a new simplified version number, provides more information about Podest in the Settings app, namely version, subscription, and expiration date for free trials. On iPad, episode images are displayed in the correct size. Large titles are refrained. And while it’s springtime round these parts, it’s time for new icon colors.

From now on versions will be counted in whole numbers, eight, nine, 10, etc., with a relative build number, for example, 8 (2) for version eight, build two. Patches are going to be counted after a dot, 8.1, say. Full-on Semantic Versioning didn’t prove itself practical for this app.

Thanks to ABI stability, app size is down to five megabytes. Good job, Swift team.

## 7.9.7 (2019-03-20)

Superfluous spaces in episode summaries have been removed.

Messaging in the Queue has been adjusted and its background set to white. For some users, after the initial iCloud sync, an incorrect message had been displayed, that’s fixed now.

The in-app store layout has been reorganized and the store now features app rating and review incentives.

The clipped search list regression is cleared.

## 7.9.6 (2019-02-27)

Accompanying the previous release to compensate a regression in search, this patch groups search suggestions correctly again and reduces latency for a smoother search experience.

Smarter placeholding and prefetching makes image loading almost seemless.

## 7.9.5 (2019-01-22)

Wishing you a very Happy New Year, it can only get better.

This release brings many things. More generous layout, allowing larger images, increased spacing, and improved support for Dynamic Type. List scrolling and animations are smoother now.

Background downloading has been further improved to work more reliably.

I almost forgot, the in-app purchases store got a nicer layout, looking better on iPad. Also, the store button has been relabeled and moved from right to left.

## 7.9.4 (2018-12-19)

100% open source, bug fixes, and small improvements. This is a packed update, here’s the rundown:

Prevent rare crash during background downloading by correctly invalidating reachability probes.

Reduce IO by removing stale downloads at more appropriate times.

Better episode summary parsing, correcting spaces, skipping invalid URLs, etc.

Sometimes it was not possible to enqueue an episode. Removing iCloud sync timers resolved this issue. Cleaning this code path, notification observing has been replaced by delegation.

Flipping the device between portrait and landscape while playing video would sometimes impair navigation, this annoyance has been resolved.

Automatic selection when entering landscape with no episode selected now picks the episode currently in the player.

Transitioning animations from mini-player to player and vice versa have been improved.

For larger screens, images in suitable sizes are loaded. A thin gray frame has been added around images.

Typography has been improved by moving to larger font sizes.

Moving between portrait and landscape modes while searching is solid now.

And most importantly, Podest is fully open source now. All source code is on GitHub.

https://github.com/michaelnisi/podest

## 7.9.3 (2018-10-15)

Improved image loading and new icon.

## 7.9.2 (2018-10-01)

I’m happy we were able to resolve an annoyingly hard to reproduce issue, where, under specific circumstances, the Queue was mismatching images. https://github.com/kean/Nuke/pull/190#event-1875458494

At the same time redundant image loading requests have been squeezed out for quicker lists.

Update for even smoother scrolling.

## 7.9.1 (2018-09-23)

On the occasion of new devices, layout has been revised, with the mini-player now better respecting the notch. While being at it, I’ve added some gestures. You can now swipe for bringing up or dismissing the player. Generally, interaction with the player has been improved.

Apropos player, playback got more stable. Frantically tapping player buttons, while playing locally or streaming should cause no problems anymore. Let me know if you can crash the player.

Another layout patch loads correct image sizes, relative to layout, especially apparent on iPad. Speaking of images, the image loading framework has been updated to Nuke 7.3.2 https://github.com/kean/Nuke

## 7.9.0 (2018-09-16)

AirPlay for audio and video. Properly supporting both wasn’t clear-cut at first, but I found an OK compromise. Please provide feedback if you should run into any problems with AirPlay in your setup.

Scrubbing. That’s right, from Control Center and the Lock Screen, you can now move playback time position back and forth.

Regaring the queue, playing episodes are always enqueued again and new episodes from pull-to-refresh updates of subscribed podcasts update the queue as well.

Two minor layout issues have been resolved, displaying the video player in landscape mode no longer flashes the status bar and the podcast title in the episode view adjusts its width now.

Optimizing for iOS 12, all code has been updated to Swift 4.2 and CloudKit change token encoding has been adjusted.

## v7.8.0 (2018-09-05)

Automatic enqueuing and dequeuing, better syncing with iCloud and plenty improvements.

Finally, we automatically enqueue the newest episode of a podcast when subscribing to it and, correspondingly, dequeue its episodes when unsubscribing. This makes subscribing more transparent and satisfying.

Syncing with iCloud has been improved to be more reliable and effective, accumulating quickly succeeding changes, for example. The truth lies in the cloud. Deleting iCoud storage, purges local caches. I’ve written a general blog post about CloudKit in the process https://troubled.pro/2018/08/cloudkit.html

For downloading, we now differentiate between cancelling downloads and removing files. Downloads are expensive, thus aren’t deleted flippantly anymore.

Messages in list backgrounds fade in and out now.

A problem identifying feeds with root URLs, URLs without paths, has been detected and fixed throughout the system.

Snapshotting for the app switcher while updating in the background works correctly now.

In some cases the add/remove buttons in the episode view got stuck, this has been resolved.

With a more granular logging setup, it’s now mostly disabled for releases.

## v7.7.0 (2018-08-02)

These are some finer grained changes from the Dept. of Technical Debt, but minor new features as well, hence the version bump.

Improves episode view with a translucent navigation bar and by clearing the text selection when the display mode changes. Also, requires confirmation before dequeueing episodes, prompting an action sheet.

Access to the in-app store is subtler timed now, receipt syncing and validation has been improved, mostly by isolating the store for easier testing. Products are not cached anymore, but always fetched from the App Store. Reachability checks have been delegated out of the actual in-app store code.

Better handling of iCloud user account switching. Nasty to test, thanks for asking. Recreates user deleted zones, assuming you might just disable iCloud for this app in Settings.

Unsubscribing from a feed also requires confirmation now. Also in the list view: preventing an indicator display glitch, text selection in the header has been disabled. Plus, pull-to-refresh while offline is OK now. Layout issues regarding the header have been resolved.

Updates image caching and preheating, synchronizes access of cached image URLs.

Cultivates less chatty logging.

## v7.6.1 (2018-07-20):

The public launch surfaced some issues, here are the changes.

In the in-app store, improved event handling, prettier colors, layout, and tighter wording.

Tolerate rare condition during background downloading, where the callback receives the same session identifier multiple times.

A layout issue in list header for iPhone X has been resolved, applying a better margin now.

## v7.6.0 (2018-07-11):

Welcome to the App Store. The first version that has been has been approved for the App Store activated the store for in-app purchases, resolving a multitude of layout issues.

## v7.5.1 (2018-07-04):

Retrying failed downloads when reachability of hosts has changed.

Actually respecting Mobile Data settings, canceling in-flight downloads, when settings change.

A bug, where when returning from landscape to portrait mode and navigating back to a list, the table view header wasn’t populated, has been fixed. Another bug, regarding misguided error messages, also in the list, has been fixed as well.

Flipping from portrait to landscape selects a reasonable item now.

By more durable and effective caching, images load quicker now.

## v7.5.0:

Regularly, but not too soon, remove unused media files.

Expose settings for Automatic Downloads, and two Mobile Data properties: Downloads and Streaming. Users can now keep Mobile Data enabled, but opt out of downloading and streaming while being not on Wi-Fi.

Always show podcast summary at the top of its episode list.

Lesser requests through smarter, more dynamic, time-to-live negotiation and off-loading some caching to URLCache.

More aggressive pull-to-refresh, not only reloading, but replacing feeds and entries, enabling users to fix inconsistent cache state, like entry doublets for example.

## v7.4.0 (2018-06-14):

Finally, the iPad version got some love. An issue with not resetting dynamic row insets while searching has been resolved. After some pushback, messaging while the Queue is empty has been improved. Also, to make it more actionable, the search bar is not longer hidden when the Queue is empty. Layouts have been improved to work better on iPhone X.

The layout of the player works for all traits now. Disabling and enabling of backward and forward controls, when the start or the end of the queue has been reached, has been implemented. The title button doesn’t flicker anymore when changed. Smaller images are being used as placeholders, while large images are loading. This image loading technique was extended throughout the app and needs to be test reviewed, especially regarding table views. Also, images are slightly larger now.

Updating only enqueues the latest episode per feed, so less trimming is required and less data needs to be synced. Updating is more frequent, not relying solely on background fetches anymore, they can’t be trusted. Background fetch crasher has been fixed. Also, timeout limit of the HTTP client has been lowered to 20 seconds.

Swipe delete animation in queue table view has been fixed. The table view can now be udpated with and without animations.

Handling of HTTP redirects has been improved. Subscriptions of HTTP redirected feed URLs get resubscribed now, removing the original URL and adding the new URL. Enqueued entries of redirected feeds get dequeued after a while.

Sync, that complex beast of a commodity, has been reviewed and should be in a satisfactory state.

And finally, after seeing the network indicator sometimes getting stuck, it’s now reset when the app moves into the background.

## v7.3.3 (2018-05-28):

After introducing strict preconditions, making sure there’s no hidden networking or IO on the main queue, the app consequently trapped while pausing and resuming streamed playback. Also, file IO, while checking if enclosures are locally available, became apparent. These issues have been resolved by introducing a worker queue, in the Playback framework, and by moving reachability checks into the playback session, of said framework.
