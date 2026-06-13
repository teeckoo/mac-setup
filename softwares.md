<ins>Install packages :-</ins>

`curl -L -o brewFile.user https://raw.githubusercontent.com/teeckoo/mac-setup/main/brewFile.user`

`brew bundle --verbose --file=brewFile.user`

`rm brewFile.user`

---

### <ins>Note :  (for non admin user only)</ins>

**coursier**, **direnv**, **wget**, **awscli**, **slack** builds dependencies from source, which is very slow, so install manually   
**bat**, **gnupg**, **eza** even though builds dependencies from source, yet installation fails, so install manually   
**tinytex** is not supported via homebrew. so install manually

### <ins>For admin user :<ins>

coursier, direnv, wget, bat, gnupg, tinytex can be installed directly with brew
