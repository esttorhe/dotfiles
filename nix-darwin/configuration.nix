{ lib, config, pkgs, ... }:
{
  # Enable experimental nix command and flakes
  # nix.package = pkgs.nixUnstable;
  nix.extraOptions = ''
    auto-optimise-store = true
    experimental-features = nix-command flakes
  '' + lib.optionalString (pkgs.system == "aarch64-darwin") ''
    extra-platforms = aarch64-darwin
  '';

  # Make sure the nix daemon always runs
  services.nix-daemon.enable = true;
  nixpkgs.config.allowUnsupportedSystem = true;
  nixpkgs.config.allowBroken = true;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "discord"
    "obsidian"
    "raycast"
    "rescuetime"
    "slack"
    "spotify"
    "telegram"
    "vscode"
    "yazi"
  ];
  nix.package = pkgs.nix;

  # Apps
  # `home-manager` currently has issues adding them to `~/Applications`
  # Issue: https://github.com/nix-community/home-manager/issues/1341
  environment.systemPackages = with pkgs; [
    alacritty
    atuin
    commitizen
    discord
    docker
    element-desktop
    eza
    fx
    fzf
    git-crypt
    htop
    httpie
    imagemagick
    jq
    keybase
    libsixel
    meld
    mosh
    neovim
    obsidian
    raycast
    rescuetime
    ripgrep
    ripgrep-all
    slack
    spotify
    terminal-notifier
    tmux
    tree
    wget
    wtf
    zsh-syntax-highlighting
  ];
  programs.nix-index.enable = true;

  # Fonts
  fonts.fontDir.enable = true;
  fonts.fonts = with pkgs; [
     recursive
     (nerdfonts.override { fonts = [ "FiraCode" ]; })
   ];

  imports = [ ./system.nix ];

  homebrew = {
    enable = true;
    onActivation.upgrade = true; 
    onActivation.autoUpdate = true;

    taps = [ "homebrew/cask-fonts" ];
  
    casks = [
      "1password-cli"
      "amethyst"
      "anki"
#      "asana"
      "calibre"
      "daisydisk"
#      "figma"
      "font-symbols-only-nerd-font"
      "handbrake"
      "imageoptim"
      "keybase"
      # "kindle"
      # "monitorcontrol"
      "notion"
      "proxyman"
      "rescuetime"
      "selfcontrol"
      "sequel-pro"
      "teensy"
      "telegram"
      "wkhtmltopdf"
      "yacreader"
    ];

    brews = [
      "adns"
      "aom"
      "autoconf"
      "automake"
      "aws-iam-authenticator"
      #"awscli"
      "bdw-gc"
      "berkeley-db"
      "brotli"
      "c-ares"
      "cairo"
      "cmake"
      "coreutils"
      "cscope"
      "curl"
      "dfu-util"
      "diff-so-fancy"
      "doctl"
      "ffmpeg"
      "flac"
      "fontconfig"
      "freetype"
      "frei0r"
      "fribidi"
      "fzf"
      "gcc"
      "gdbm"
      "ghostscript"
      "giflib"
      "git-delta"
      "glib"
      "gmime"
      "gmp"
      "gnu-getopt"
      "gnu-sed"
      "gnupg"
      "gnutls"
      "gobject-introspection"
      "gpgme"
      "graphite2"
      "guile"
      "harfbuzz"
      "icu4c"
      "imagemagick"
      "ipmitool"
      "isl"
      "isync"
      "jansson"
      "jemalloc"
      "jpeg"
      "k9s"
      "krb5"
      "kubernetes-cli"
      "lame"
      "lcov"
      "ldns"
      "leptonica"
      "libass"
      "libassuan"
      "libbluray"
      "libcbor"
      "libde265"
      "libev"
      "libevent"
      "libffi"
      "libfido2"
      "libgcrypt"
      "libgpg-error"
      "libheif"
      "libidn2"
      "libksba"
      "liblqr"
      "libmetalink"
      "libmpc"
      "libogg"
      "libomp"
      "libpng"
      "libsamplerate"
      "libsndfile"
      "libsoxr"
      "libssh2"
      "libtasn1"
      "libtiff"
      "libtool"
      "libunistring"
      "libusb"
      "libvidstab"
      "libvo-aacenc"
      "libvorbis"
      "libvpx"
      "libyaml"
      "libzip"
      "little-cms2"
      "lzo"
      "make"
      "mas"
      "mpfr"
      "ncdu"
      "ncurses"
      "nettle"
      "nghttp2"
      "notmuch"
      "npth"
      "oniguruma"
      "opencore-amr"
      "openexr"
      "openjpeg"
      "openssh"
      "openssl@1.1"
      {
        name = "openssl@3"; 
        link = true;
      }
      "opus"
      "p11-kit"
      "packer"
      "pam-reattach"
      "pcre"
      "pdsh"
      "pinentry"
      "pipX"
      "pixman"
      "pkg-config"
      "python@3.11"
      "rav1e"
      "readline"
      "rtmpdump"
      "rubberband"
      "s3cmd"
      "sdl2"
      "shared-mime-info"
      "shellcheck"
      "snappy"
      "speex"
      "sqlite"
      "srt"
      "talloc"
      "tesseract"
      "tfenv"
      "the_silver_searcher"
      "thefuck"
      "theora"
      "tig"
      "tldr"
      "tokyo-cabinet"
      "trash-cli"
      # "tree"
      "unbound"
      "unixodbc"
      "urlview"
      "utf8proc"
      "webp"
      "wtfutil"
      "x264"
      "x265"
      "xapian"
      "xmlto"
      "xvid"
      "xz"
      "yazi"
      "z"
      "zlib"
      "zstd"
    ];

    #masApps = {
    #  "TickTick:To-Do List, Calendar" = 966085870;
    #};
  };
}
