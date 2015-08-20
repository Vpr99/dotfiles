#!/usr/bin/env bash

#==============================================================================
# Installs Homebrew and some handy tools
#
# Packages:
# - Wget (W/ IRI Support)
# - Brew Cask
# - Git
# - Libsass
# - Node.js
#
#==============================================================================

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Installs Xcode Command Line Tools
xcode-select --install
read -rsp $'Press any key to continue when Xcode CLT is done...\n' -n1 key

# Install Homebrew
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Make sure we’re using the latest Homebrew.
brew update
echo Homebrew installed. Now some plugins...

# Upgrade any already-installed formulae.
brew upgrade --all

# Install other useful binaries
brew install wget --with-iri
brew install caskroom/cask/brew-cask
brew tap caskroom/versions # enable alternate versions of Casks

# Install useful dev envornment tools
brew install git
brew install libsass
brew install node

# Remove outdated versions from the cellar.
brew cleanup
