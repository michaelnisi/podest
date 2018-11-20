# Podest - Get your podcasts

Podest is a podcast player app for iOS making podcasts simple. I’ve written about my motivation [here](https://troubled.pro/2018/10/podest.html). Download the app on the [App Store](https://itunes.apple.com/us/app/podest/id794983364) and leave a rating or review to support this project.

## Dependencies

- [fanboy-kit](https://github.com/michaelnisi/fanboy-kit), Search podcasts via proxy
- [feedkit](https://github.com/michaelnisi/feedkit), Get feeds and entries
- [fileproxy](https://github.com/michaelnisi/fileproxy), Manage background downloads
- [hattr](https://github.com/michaelnisi/hattr), Convert HTML to attributed strings
- [manger-kit](https://github.com/michaelnisi/manger-kit), Request podcasts via proxy
- [nuke](https://github.com/michaelnisi/nuke), A powerful image loading and caching system
- [ola](https://github.com/michaelnisi/ola), Check reachability
- [patron](https://github.com/michaelnisi/patron), JSON HTTP client
- [skull](https://github.com/michaelnisi/skull), Swift SQLite

### Yet to be released as open source

- [playback](https://github.com/michaelnisi/playback), Play audio and video

## Services

- [fanboy-http](https://github.com/michaelnisi/fanboy-http), Search podcasts
- [manger-http](https://github.com/michaelnisi/manger-http), Browse podcasts

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
