#!/usr/bin/env bash

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until this file has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &


#==============================================================================
# Reconfigures a lot of OSX default settings to generally make the OS better.
#==============================================================================
sh osx/system.sh
sh osx/finder.sh
sh osx/dock.sh
