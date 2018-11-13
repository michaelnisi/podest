# Podest - Get your podcasts

Podest is a podcast player app for iOS. Download on the [App Store](https://itunes.apple.com/us/app/podest/id794983364) and leave a rating or review to support this project.

## Dependencies

- fanboy-kit
- feedkit
- [hattr](https://github.com/michaelnisi/hattr) Convert HTML to attributed strings
- manger-kit
- [nuke](https://github.com/michaelnisi/nuke) A powerful image loading and caching system
- [ola](https://github.com/michaelnisi/ola) Check reachability of host
- [patron](https://github.com/michaelnisi/patron) JSON HTTP client
- playback
- [skull](https://github.com/michaelnisi/skull) Swift SQLite

## Services

- [fanboy-http](https://github.com/michaelnisi/fanboy-http) Search iTunes for podcast feeds
- manger-http

## Install

To setup the project for development, cloning repos of dependencies to `../`, do.

```
./tools/setup
```

Then some app configuration files need to be generated. Check the script to see the variables it expects.

```
./tools/configure
```

## License

[MIT](https://raw.github.com/michaelnisi/podest/master/LICENSE)
