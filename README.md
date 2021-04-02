# dotfiles
My very own dotfiles (intended mostly for when I change computers)

## Scripts

The scripts are just a copy of [Holman's dotfiles scripts][holman] with a little modification from me.

Here's the important part of [Holman's dotfiles scripts][holman]:

>## components
>
>There's a few special files in the hierarchy.
>
>- **bin/**: Anything in `bin/` will get added to your `$PATH` and be made
  available everywhere.
>- **Brewfile**: This is a list of applications for [Homebrew Cask](http://caskroom.io) to install: things like Chrome and 1Password and Adium and stuff. Might want to edit this file before running any initial setup.
>- **topic/\*.zsh**: Any files ending in `.zsh` get loaded into your
  environment.
>- **topic/path.zsh**: Any file named `path.zsh` is loaded first and is
  expected to setup `$PATH` or similar.
>- **topic/completion.zsh**: Any file named `completion.zsh` is loaded
  last and is expected to setup autocomplete.
>- **topic/\*.symlink**: Any files ending in `*.symlink` get symlinked into
  your `$HOME`. This is so you can keep all of those versioned in your dotfiles
  but still keep those autoloaded files in your home directory. These get
  symlinked in when you run `script/bootstrap`.

I'm not claiming I did much except the addition of `symfolder`.
The `.symfolder` extension lets you set a folder with that extension and everything inside of it will be symlinked to that dotfolder.

- **topic/\*.symfolder**: Any folder ending in `*.symfolder` get symlinked into
  your `$HOME` inside of that dotfolder. 
  These get symlinked in when you run `script/bootstrap`.
  
  e.g.
  ```bash
  mutt.symfolder
  ﹂accounts
    ﹂account.account
  ﹂msmtprc
  ```
  
  This means that everything under `mutt.symfolder` will be symlinked to `~/.mutt/`.
  Probably Holman`s script already works this way but I wanted to have a way to differentiate between files and folder contents.

===

# *nix

For a better integration of `AppImage` files install [`AppImageLauncher`][appimagelauncher]. This will generate .desktop files as well as move the images to a centralised location and integrate them with the app launcher of choice.

===

After some refactoring I extracted some [`shared_functionality`](script/shared_functionality) to its own script and then I'm must `source`ing it where needed.

e.g.:
[`LaunchAgents` install script](osx/LaunchAgents/install.sh#L3:L5)

# Acknowledgments
* [Zack Holman][holman]
* [Benedikt Terhechte | Pre-commit hooks][hooks]

[holman]:https://github.com/holman/dotfiles
[hooks]:http://appventure.me/2016/04/04/prevent-accidental-test-code-commits/
[appimagelauncher]:https://itsfoss.com/use-appimage-linux/
