#!/bin/bash

echo 'Applying macOS system defaults...'

defaults write NSGlobalDomain _HIHideMenuBar "true"
defaults write NSGlobalDomain AppleKeyboardUIMode "3"
defaults write NSGlobalDomain ApplePressAndHoldEnabled "false"
defaults write NSGlobalDomain InitialKeyRepeat "10"
defaults write NSGlobalDomain KeyRepeat "1"
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled "false"
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled "false"
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled "false"
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled "false"
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled "false"
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode "true"
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 "true"
defaults write dock autohide "true"
defaults write dock mru-spaces "false"
defaults write dock orientation "bottom"
defaults write dock showhidden "true"
defaults write finder AppleShowAllExtensions "true"
defaults write finder FXEnableExtensionChangeWarning "false"
defaults write finder QuitMenuItem "true"
defaults write trackpad Clicking "true"
defaults write trackpad TrackpadThreeFingerDrag "true"

defaults write -g ApplePressAndHoldEnabled -bool false
defaults write com.apple.iTunes disablePing -bool true
defaults write com.apple.screencapture disable-shadow -bool true
defaults write com.apple.BezelServices kDimTime -int 300
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.finder FXDefaultSearchScope -string “SCcf”
defaults write com.apple.finder QLEnableTextSelection -bool true
chflags nohidden ~/Library
defaults write com.apple.dock show-process-indicators -bool true
defaults write com.apple.menuextra.battery ShowTime -bool true
sudo networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.dock wvous-tr-modifier -int 0
defaults write com.apple.finder AppleShowAllExtensions -boolean true
defaults write NSGlobalDomain KeyRepeat -int 0
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4
defaults write com.apple.screensaver askForPasswordDelay -int 0
defaults write com.apple.dock wvous-tl-corner -int 2
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write com.apple.TextEdit RichText -int 0
defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write com.apple.Finder FXPreferredViewStyle Nlsv
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.addressbook ABShowDebugMenu -bool true
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.menuextra.battery ShowPercent -bool true
defaults write com.apple.iTunes disablePingSidebar -bool true
defaults write com.apple.Safari ShowFavoritesBar -bool false
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
defaults write com.apple.dock tilesize -int 16
defaults write com.apple.DiskUtility advanced-image-options -bool true
defaults write com.apple.dock expose-animation-duration -int 0
killall Dock
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.dock wvous-tr-corner -int 5
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
defaults write com.apple.BezelServices kDim -bool true
defaults write com.apple.iTunes disableGeniusSidebar -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write com.apple.dock wvous-tl-modifier -int 0
