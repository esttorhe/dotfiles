#!/usr/bin/env bash

# Sets reasonable OS X defaults.
#
# Or, in other words, set shit how I like in OS X.
#
# The original idea (and a couple settings) were grabbed from:
#   https://github.com/holman/dotfiles/blob/master/osx/set-defaults.sh
#

# Only setup defaults if running on MacOS
if [ "$(uname -s)" = "Darwin" ]; then

    # Disable press-and-hold for keys in favor of key repeat.
    defaults write -g ApplePressAndHoldEnabled -bool false
    
    # Always open everything in Finder's list view. This is important.
    defaults write com.apple.Finder FXPreferredViewStyle Nlsv
    
    # Show the ~/Library folder.
    chflags nohidden ~/Library
    
    # Finder: Shows all extensions
    defaults write com.apple.finder AppleShowAllExtensions -boolean true
    
    # Set a really fast key repeat.
    defaults write NSGlobalDomain KeyRepeat -int 0
    
    # Set the Finder prefs for showing a few different volumes on the Desktop.
    defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
    defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
    
    # Hot corners
    # Possible values:
    #  0: no-op
    #  2: Mission Control
    #  3: Show application windows
    #  4: Desktop
    #  5: Start screen saver
    #  6: Disable screen saver
    #  7: Dashboard
    # 10: Put display to sleep
    # 11: Launchpad
    # 12: Notification Center
    
    # Run the screensaver if we're in the top-right hot corner.
    defaults write com.apple.dock wvous-tr-corner -int 5
    defaults write com.apple.dock wvous-tr-modifier -int 0
    
    # Top left screen corner → Desktop
    defaults write com.apple.dock wvous-tl-corner -int 2
    defaults write com.apple.dock wvous-tl-modifier -int 0
    
    # Menu bar: show remaining battery time (on pre–10.8); hide percentage
    defaults write com.apple.menuextra.battery ShowPercent -bool true
    defaults write com.apple.menuextra.battery ShowTime -bool true
    
    # Hide Safari's bookmark bar.
    defaults write com.apple.Safari ShowFavoritesBar -bool false
    
    # Makes Xcode build with all available CPUs
    defaults write com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks `sysctl -n hw.ncpu`
    
    # Makes Xcode show build times
    defaults write com.apple.dt.Xcode ShowBuildOperationDuration -bool YES
    
    # Changes Screenshot location to ~/Downloads/Screenshots
    if [ ! -d "$HOME/Downloads/Screenshots" ]; then
      mkdir "$HOME/Downloads/Screenshots"
    fi
    defaults write com.apple.screencapture location $HOME/Downloads/Screenshots; killall SystemUIServer
    
    # Expand save panel by default
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
    
    # Save to disk (not to iCloud) by default
    defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
    
    # Trackpad: enable tap to click for this user and for the login screen
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    
    # Require password immediately after sleep or screen saver begins
    defaults write com.apple.screensaver askForPassword -int 1
    defaults write com.apple.screensaver askForPasswordDelay -int 0
    
    # Disable shadow in screenshots
    defaults write com.apple.screencapture disable-shadow -bool true
    
    # Finder: show hidden files by default
    defaults write com.apple.finder AppleShowAllFiles -bool true
    
    # Finder: allow text selection in Quick Look
    defaults write com.apple.finder QLEnableTextSelection -bool true
    
    # When performing a search, search the current folder by default
    defaults write com.apple.finder FXDefaultSearchScope -string “SCcf”
    
    # Avoid creating .DS_Store files on network volumes
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    
    # Disable the warning when changing a file extension
    defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
    
    # Set the icon size of Dock items to 16 pixels
    defaults write com.apple.dock tilesize -int 16
    
    # Show indicator lights for open applications in the Dock
    defaults write com.apple.dock show-process-indicators -bool true
    
    # Speed up Mission Control animations
    defaults write com.apple.dock expose-animation-duration -float 0.1
    
    # Disable the Genius sidebar in iTunes
    defaults write com.apple.iTunes disableGeniusSidebar -bool true
    
    # Disable the Ping sidebar in iTunes
    defaults write com.apple.iTunes disablePingSidebar -bool true
    
    # Disable all the other Ping stuff in iTunes
    defaults write com.apple.iTunes disablePing -bool true
    
    # Prevent Time Machine from prompting to use new hard drives as backup volume
    defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
    
    # Enable the debug menu in Address Book
    defaults write com.apple.addressbook ABShowDebugMenu -bool true
    
    # Use plain text mode for new TextEdit documents
    defaults write com.apple.TextEdit RichText -int 0
    
    # Open and save files as UTF–8 in TextEdit
    defaults write com.apple.TextEdit PlainTextEncoding -int 4
    defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4
    
    # Enable the debug menu in Disk Utility
    defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
    defaults write com.apple.DiskUtility advanced-image-options -bool true
    
    # Auto illuminate keyboard in low light
    defaults write com.apple.BezelServices kDim -bool true
    
    # Turn off keyboard light when not used for 5 min
    defaults write com.apple.BezelServices kDimTime -int 300
    
    # Make Dock icons of hidden applications translucent
    defaults write com.apple.dock showhidden -bool true
    
    # Use google dns
    sudo networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4
    
    # Reduces animation of spaces/Exposé to 0
    defaults write com.apple.dock expose-animation-duration -int 0; killall Dock
    
    killall Finder
    killall Dock
    killall SystemUIServer
    
    # To stop Xcode from reopening files (storyboards) on launch
    defaults write com.apple.dt.Xcode IDEDisableStateRestoration -bool true

fi
# vim: ft=sh
