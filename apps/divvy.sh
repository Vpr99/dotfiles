# # Add proper colum and row #
# defaults write com.mizage.Divvy lastColumnCount -int 10
# defaults write com.mizage.Divvy lastRowCount -int 10
# defaults write com.mizage.Divvy defaultRowCount -int 10
# defaults write com.mizage.Divvy defaultColumnCount -int 10
#
# # Set up other configuration
# defaults write com.mizage.Divvy useGlobalHotkey -bool YES
# defaults write com.mizage.Divvy showMenuIcon -bool NO
# defaults write com.mizage.Divvy enableMargins -bool YES
# defaults write com.mizage.Divvy useDefaultGrid -bool YES
# defaults write com.mizage.Divvy mustDismissPanel -bool YES
#
# echo Divvy has been configured. You still need to add Shortcuts & Global Hotkey


cp -RfXv "../apps/prefs/com.mizage.Divvy.plist" "/Users/ericskram/Library/Preferences"
