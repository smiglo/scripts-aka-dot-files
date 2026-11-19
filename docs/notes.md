- list listening TCP ports
  ```bash
  lsof -nP -iTCP -sTCP:LISTEN
  ss -tunsl
  ```
- yt to mp3
  ```bash
  yt-dlp -x --audio-format mp3 URI
  ```
