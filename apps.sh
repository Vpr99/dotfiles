#!/usr/bin/env bash

#==============================================================================
# Install various applications
#==============================================================================

export HOMEBREW_CASK_OPTS="--appdir=/Applications"

echo Installing Core apps
brew cask install dropbox
brew cask install 1password

echo Installing Development apps
brew cask install iterm2-beta
brew cask install atom
sh apps/atom.sh
brew cask install imageoptim
brew cask install imagealpha
brew cask install sourcetree
brew cask install sketch-tool
sh apps/sketch.sh
brew cask install zeplin

echo Installing Media apps
brew cask install google-chrome-canary
sh apps/chrome.sh
brew cask install spotify
brew cask install vlc
brew cask install slack
brew cask install subler
brew cask install transmission
sh apps/transmission.sh

echo Installing Utilities
brew cask install keka
brew cask install divvy
brew cask install appcleaner
brew cask install xslimmer
brew caks install logitech-options
