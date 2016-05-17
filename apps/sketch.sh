#==============================================================================
# Sketch App configuration
#==============================================================================

# Changes the big nudge distance from 10px to 8px
defaults write ~/Library/Preferences/com.bohemiancoding.sketch3.plist nudgeDistanceBig -int 8

# Symlink the plugins folder to Dropbox
rm -rf ~/Library/Application\ Support/com.bohemiancoding.sketch3/Plugins
ln -s ~/Dropbox/System/Plugins/Sketch/Plugins ~/Library/Application\ Support/com.bohemiancoding.sketch3/
