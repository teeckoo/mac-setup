<ins>install sdkman :-</ins>

```
brew tap "sdkman/tap"
brew install sdkman-cli
```

open new session and execute :-

```
sdk install java 17.0.11-amzn
sdk install sbt
sdk install maven
```


<ins>Install packages :-</ins>

`brew bundle --file=brewFile.user`

coursier builds dependencies from source, which is very slow, so install manually
tinytex is not supported via homebrew. so install manually
