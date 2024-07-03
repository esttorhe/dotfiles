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
    _1password
    adns
    alacritty
    atuin
    autoconf
    automake
    aws-iam-authenticator
    c-ares
    cairo
    cmake
    commitizen
    coreutils
    cscope
    curl
    dfu-util
    diff-so-fancy
    discord
    docker
    element-desktop
    eza
    ffmpeg
    flac
    fontconfig
    freetype
    frei0r
    fribidi
    fx
    fzf
    fzf
    gcc
    gdbm
    gh
    ghostscript
    giflib
    git-crypt
    glib
    gmime
    gmp
    gnupg
    gnutls
    gobject-introspection
    gpgme
    graphite2
    guile
    harfbuzz
    htop
    httpie
    imagemagick
    imagemagick
    ipmitool
    isl
    isync
    jansson
    jemalloc
    jq
    k9s
    keybase
    krb5
    lame
    lcov
    ldns
    leptonica
    libass
    libassuan
    libbluray
    libcbor
    libde265
    libev
    libevent
    libffi
    libfido2
    libgcrypt
    libgpg-error
    libheif
    libidn2
    libksba
    libmpc
    libogg
    libpng
    libsamplerate
    libsixel
    libsndfile
    libssh2
    libtasn1
    libtiff
    libtool
    libunistring
    libvorbis
    libvpx
    libyaml
    libzip
    lzo
    mas
    meld
    mosh
    mpfr
#    ncdu
#    ncurses
    neovim
    nettle
    nghttp2
    notmuch
    npth
    obsidian
    oniguruma
    opencore-amr
    openexr
    openjpeg
    openssh
    openssl_3_3
    p11-kit
    packer
    pam-reattach
    pcre
    pdsh
    pinentry_mac
    pkg-config
    platinum-searcher
    python311Full
    rav1e
    raycast
    readline
    rescuetime
    ripgrep
    ripgrep-all
    rtmpdump
    rubberband
    s3cmd
    SDL2
    shared-mime-info
    shellcheck
    slack
    snappy
    speex
    spotify
    sqlite
    srt
    talloc
    terminal-notifier
    tesseract
    thefuck
    tig
    tldr
    tmux
    trash-cli
    tree
    tree
    unbound
    unixODBC
    utf8proc
    vscode
    wget
    wtf
    x264
    x265
    xapian
    xmlto
    xz
    yazi
    zlib
    zsh-syntax-highlighting
    zstd
  ];
  programs.nix-index.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
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
      "amethyst"
      # "anki"
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
      "aom"
      "bdw-gc"
      "berkeley-db"
      "git-delta"
      "gnu-getopt"
      "gnu-sed"
      "icu4c"
      "jpeg"
      "kubernetes-cli"
      "liblqr"
      "libmetalink"
      "libomp"
      "libsoxr"
      "libusb"
      "libvidstab"
      "libvo-aacenc"
      "little-cms2"
      "make"
      "openssl@1.1"
      "opus"
      "pipX"
      "pixman"
      "tfenv"
      "theora"
      "tokyo-cabinet"
      "urlview"
      "webp"
      "wtfutil"
      "xvid"
      "z"
      "zstd"
    ];

    masApps = {
     "TickTick:To-Do List, Calendar" = 966085870;
    };
  };
}
