
# Symlink the plugins folder to Dropbox
rm -rf ~/Library/Application\ Support/com.bohemiancoding.sketch3/Plugins
ln -s ~/Dropbox/System/Plugins/Sketch/Plugins ~/Library/Application\ Support/com.bohemiancoding.sketch3/

# Install all Dropbox fonts
cp -a ~/Dropbox/System/Fonts/. ~/Library/Fonts

# Move the atom gist
cat ~/Dropbox/System/Config/atom.txt >> ~/.atom/config.cson

rm -rf ~/Library/Preferences/com.mizage.direct.Divvy.plist
rm -rf ~/Library/Preferences/com.mizage.Divvy.plist

ln -s ~/Dropbox/System/Config/com.mizage.Divvy.plist ~/Library/Preferences/
ln -s ~/Dropbox/System/Config/com.mizage.direct.Divvy.plist ~/Library/Preferences/

echo Download the following from the App Store:
echo  - Tweetbot
echo  - Affinity Designer
echo  - Affinity Photo
echo  - Keynote
echo  - Pages
echo  - Numbers
