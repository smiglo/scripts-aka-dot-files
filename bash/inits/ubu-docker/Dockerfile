FROM ubuntu:24.04

ARG UNAME=tom
ARG UID
ARG GID
ARG DOCKER_CONF_F=/etc/docker-ubu.conf
ARG DEBIAN_FRONTEND=noninteractive

ENV LANG=C.UTF-8
ENV USER=$UNAME

RUN apt-get update -yq && apt-get install -y \
      ca-certificates sudo coreutils && \
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y unminimize && \
      yes | unminimize || true && \
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends --fix-missing \
      software-properties-common build-essential apt-utils && \
      yes | add-apt-repository main && \
      yes | add-apt-repository universe && \
      yes | add-apt-repository restricted && \
      yes | add-apt-repository multiverse && \
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends --fix-missing \
      moreutils whiptail \
      net-tools iproute2 traceroute inetutils-ping \
      unzip wget curl ssh calc xxd gpg less rlwrap socat netcat-openbsd strace tcpdump \
      file tree highlight \
      openssl openssh-server libssl-dev sshpass \
      bash-completion \
      man locales locate \
      rsync \
      vim-gtk3 && \
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends --fix-missing \
      gcc g++ clang \
      gdb-multiarch valgrind radare2 rr \
      exuberant-ctags cscope \
      cmake ninja-build pkg-config \
      manpages-dev manpages-posix-dev && \
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends --fix-missing \
      git tig quilt \
      gawk silversearcher-ag tmux fzf \
      pv at cmatrix mc grc vlock jq expect colordiff bsdmainutils htop \
      bat entr xclip xsel ack psmisc fd-find bfs psmisc && \
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends \
      python3 python3-pip && \
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends \
      nodejs && \
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends \
      openssh-server && \
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

RUN echo 'root:$6$6zXnZ0CSN/J/GH$wuY0vms.LvV6e9hEAl48hcgA7e290G3DicR3gp.f1I5OfxKYItG61RmjHyWv9Up25HioQ1u.Xxtv4Mqo4DspV0' | chpasswd -e

RUN groupadd -g $GID -o $UNAME
RUN groupadd sudo || true
RUN userdel ubuntu || true
RUN useradd -m -u $UID -g $GID -G sudo,adm -o -s /bin/bash $UNAME
RUN echo "$UNAME:"'$6$osyfPO4j/$IleqfRUYu/hmor03SYdya51QhtJeMukAIgkD6LcCTvqgDY7TXTpqQwJNyhHee0D7o0In/FcJdmmtLxRvxpN2C1' | chpasswd -e

RUN echo "$UNAME	ALL=(ALL:ALL) ALL" >>/etc/sudoers

RUN mv /usr/bin/hostname /usr/bin/hostname.bck && \
    echo "echo ubu" >/usr/bin/hostname && \
    chmod a+rx /usr/bin/hostname

RUN locale-gen en_US.UTF-8 pl_PL.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_NAME=pl_PL.UTF-8

ENV TZ="Europe/Warsaw"
RUN date

COPY ubu.conf /tmp/

RUN \
    echo 'DOCKER_CONF_PWD_USER=' >>$DOCKER_CONF_F && \
    echo 'DOCKER_CONF_PWD_ROOT=' >>$DOCKER_CONF_F && \
    echo >>$DOCKER_CONF_F && \
    cat /tmp/ubu.conf >>$DOCKER_CONF_F && \
    rm -f /tmp/ubu.conf

# ------------------

ARG SCRIPT_PATH
ARG DOCKER_CONF_EXT

USER $UNAME

RUN mkdir -p /home/$UNAME/tools

RUN ln -sf /home/$UNAME/$SCRIPT_PATH/bash/inits/ubu-docker/docker-post.sh /home/$UNAME/tools/docker-post.sh
RUN if test $DOCKER_CONF_EXT != '-'; then ln -sf /host/$DOCKER_CONF_EXT /home/$UNAME/tools/docker-post-ext.sh; fi

