#!/usr/bin/env bash

#==============================================================================
# Install various applications
#==============================================================================

brew tap caskroom/cask
brew tap caskroom/versions
brew tap caskroom/fonts

echo Installing Core apps
brew cask install dropbox
brew cask install 1password
brew cask install airmail-beta

echo Installing Development apps
brew cask install iterm2
sh apps/atom.sh
brew cask install imageoptim
brew cask install imagealpha
brew cask install sourcetree
sh apps/sketch.sh
brew cask install zeplin

echo Installing Media apps
sh apps/chrome.sh
sh apps/transmission.sh
brew cask install spotify
brew cask install vlc
brew cask install slack
brew cask install subler

echo Installing Utilities
brew cask install keka
brew cask install divvy
brew cask install appcleaner
brew cask install xslimmer
brew caks install logitech-options

dockutil --add /Applications/Calendar.app
dockutil --add /Applications/Google\ Chrome.app
dockutil --add /Applications/Spotify.app
dockutil --add /Applications/Slack.app
dockutil --add /Applications/iTerm.app
dockutil --add /Applications/SourceTree.app
dockutil --add /Applications/Sketch.app
dockutil --add /Applications/Atom.app
