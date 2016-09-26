#==============================================================================
# Sketch App configuration
#==============================================================================

brew cask install sketch

# Changes the big nudge distance from 10px to 8px
defaults write ~/Library/Preferences/com.bohemiancoding.sketch3.plist nudgeDistanceBig -int 8
