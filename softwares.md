<ins>Install packages :-</ins>

`curl -L -o brewFile.user https://raw.githubusercontent.com/teeckoo/mac-setup/main/brewFile.user`

`brew bundle --verbose --file=brewFile.user`

`rm brewFile.user`

**coursier**, **direnv**, **wget** builds dependencies from source, which is very slow, so install manually   
**bat**, **gnupg** even though builds dependencies from source, yet installation fails, so install manually   
**tinytex** is not supported via homebrew. so install manually
