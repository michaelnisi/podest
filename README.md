# Podest - Get your podcasts

Podest is a podcast player app for iOS making podcasts simple. I’ve written about my motivation [here](https://troubled.pro/2018/10/podest.html). Download the app on the [App Store](https://itunes.apple.com/us/app/podest/id794983364) and leave a rating or review to support this project.

## Dependencies

- [kean/Nuke](https://github.com/kean/Nuke) A powerful image loading and caching system
- [michaelnisi/batchupdates](https://github.com/michaelnisi/batchupdates) Batch update table and collection views
- [michaelnisi/fanboy-kit](https://github.com/michaelnisi/fanboy-kit) Search podcasts via proxy
- [michaelnisi/feedkit](https://github.com/michaelnisi/feedkit) Get feeds and entries
- [michaelnisi/fileproxy](https://github.com/michaelnisi/fileproxy) Manage background downloads
- [michaelnisi/hattr](https://github.com/michaelnisi/hattr) Convert HTML to attributed strings
- [michaelnisi/manger-kit](https://github.com/michaelnisi/manger-kit) Request podcasts via proxy
- [michaelnisi/ola](https://github.com/michaelnisi/ola) Check reachability
- [michaelnisi/patron](https://github.com/michaelnisi/patron) JSON HTTP client
- [michaelnisi/playback](https://github.com/michaelnisi/playback) Play audio and video
- [michaelnisi/skull](https://github.com/michaelnisi/skull) Swift SQLite

## Services

- [michaelnisi/fanboy-http](https://github.com/michaelnisi/fanboy-http) Search podcasts
- [michaelnisi/manger-http](https://github.com/michaelnisi/manger-http) Browse podcasts

## Documentation

More interesting things happen in frameworks like [FeedKit](https://github.com/michaelnisi/feedkit), but you may also browse app [docs](https://michaelnisi.github.io/podest/index.html).

## Install

To setup for development, cloning repos of dependencies to `../`, do.

```
./tools/setup
```

Then some app configuration files need to be generated. Check the script to see the variables it expects.

```
./tools/configure
```

Build the app using a local Xcode workspace.

## License

[MIT](https://raw.github.com/michaelnisi/podest/master/LICENSE)
