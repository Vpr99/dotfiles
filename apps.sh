#!/usr/bin/env bash

#==============================================================================
# Install various applications
#==============================================================================

export HOMEBREW_CASK_OPTS="--appdir=/Applications"

echo Installing Core apps
brew cask install 1password
brew cask install bartender
brew cask install divvy
brew cask install dropbox
brew cask install xtrafinder
brew cask install keka

echo Installing Development apps
brew cask install iterm2-nightly
brew cask install atom
brew cask install imageoptim
brew cask install imagealpha
brew cask install sourcetree
brew cask install sketch-tool
brew cask install sketch-toolbox

echo Installing Media apps
brew cask install google-chrome-canary
brew cask install spotify
brew cask install vlc
brew cask install slack
brew cask install subler

echo Installing Utilities
brew cask install appcleaner
brew cask install xslimmer


#==============================================================================
# App-specific settings & configurations
#==============================================================================
sh apps/chrome.sh
sh apps/transmission.sh
sh apps/atom.sh
