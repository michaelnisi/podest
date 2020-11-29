# Podest

![Snapshots](https://troubled.pro/img/podest/se@3x.png)

## Download fine podcasts

Podest is a podcast player app for iOS making podcasts simple. I’ve written about my motivation [here](https://troubled.pro/2018/10/podest.html). Download the app on the [App Store](https://itunes.apple.com/us/app/podest/id794983364) and leave a rating or review to support this project.

## Development

### Install

As Podest uses Swift packages, not much setup is required, but some private app configuration must be generated. Check the script to see the variables it expects.

```
$ ./tools/configure
```

To setup for development cloning repos of dependencies to `../`, do.

```
$ ./tools/setup
```
Setup a local Xcode workspace with Podest adding dependency projects you want to work on.

## License

[MIT](https://raw.github.com/michaelnisi/podest/master/LICENSE)
