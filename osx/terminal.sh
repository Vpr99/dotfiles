
#==============================================================================
# Installing Fish Shell
#==============================================================================
curl -L https://github.com/oh-my-fish/oh-my-fish/raw/master/bin/install | fish
echo "/usr/local/bin/fish" | sudo tee -a /etc/shells
chsh -s /usr/local/bin/fish
omf install sushi
