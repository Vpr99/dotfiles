#==============================================================================
# Sketch App configuration
#==============================================================================

brew cask install sketch-tool

# Changes the big nudge distance from 10px to 8px
defaults write ~/Library/Preferences/com.bohemiancoding.sketch3.plist nudgeDistanceBig -int 8
