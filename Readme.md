# AudioPlayerManager

There are a lot of cheap audio player, which can't work with folder/albums despite the fact you can put there 8-16GB audio files there. This program should help you set suitable line of files (shuffle/normal order supported) for playing there as far as possible (prefers renaming to copying). You are supposed to set [TOML config file](https://en.wikipedia.org/wiki/TOML), where you set mirror of your player's audio file folders/albums and the way you want to prepare them on the player e.g.:

```
mount_folder="/home/ghibulo/programovani/dart/mountFolder"
mirror_folder="/home/ghibulo/programovani/dart/mirrorFolder"

[album]
    [album.1]
      mirror_folder="/home/ghibulo/Downloads/hudba"
      folder="flac"
      state="on"
      order="shuffle" #normal/shuffle/bigshuffle
      tracks =	[
        ["off", "01. Bad Boy.flac"],
        ["on", "06. Hard Luck Blues.flac"],
        ["on", "03. I Got Money.flac"],
        ["on", "07. Gambling Blues.flac"],
      ]

    [album.2]
      mirror_folder="/home/ghibulo/Downloads/hudba"
      folder="zp1"
      ...
```
