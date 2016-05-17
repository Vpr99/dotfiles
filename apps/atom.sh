#!/usr/bin/env bash

#==============================================================================
# atom.sh
# Sync's my Atom configuration
#==============================================================================

apm install sync-settings

cat ~/Dropbox/System/Config/atom.txt >> ~/.atom/config.cson
