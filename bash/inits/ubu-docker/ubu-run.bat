set cName="ubu"
set iName="ubu:static"
set hDir=/home/tom
set HOME=D:\tools\docker-ubu

set dockerHost=%USERPROFILE%\docker-ubu
set runtimeDir=%dockerHost%\runtime
set sshDir=%dockerHost%\ssh

docker container stop %cName%
docker container rm %cName%

docker run ^
  --hostname ubu -u 1000:1000 -dit ^
  --cap-add=SYS_PTRACE --security-opt seccomp=unconfined ^
  --tmpfs /tmpfs:exec,mode=1777 ^
  -v %runtimeDir%:%hDir%/.runtime ^
  -v %sshDir%:%hDir%/.ssh ^
  -v %HOME%:/host ^
  -v %HOME%\share:%hDir%/share ^
  -v %dockerHost%\projects:%hDir%/projects ^
  -w /home/tom ^
  --name %cName% %iName% ^
  /bin/bash

docker start %cName%
docker attach %cName%
