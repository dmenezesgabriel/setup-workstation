echo "Create NerdFonts directory"
[-d ~/NerdFonts] || mkdir -p ~/NerdFonts
echo "Change directory to NerdFonts"
cd ~/NerdFonts
echo "Download FiraCode font"
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/FiraCode.zip
echo "Unzip FiraCode"
unzip FiraCode.zip
# cp FiraCode<font>.ttf ~/termux/font.ttf
