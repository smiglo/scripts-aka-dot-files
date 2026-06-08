FROM ubuntu:24.04

ARG UNAME=tom
ARG UID
ARG GID
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN true
ARG USER_PWD='$6$osyfPO4j/$IleqfRUYu/hmor03SYdya51QhtJeMukAIgkD6LcCTvqgDY7TXTpqQwJNyhHee0D7o0In/FcJdmmtLxRvxpN2C1'
ARG ROOT_PWD='$6$6zXnZ0CSN/J/GH$wuY0vms.LvV6e9hEAl48hcgA7e290G3DicR3gp.f1I5OfxKYItG61RmjHyWv9Up25HioQ1u.Xxtv4Mqo4DspV0'

ENV LANG=C.UTF-8
ENV USER=$UNAME

RUN apt-get update -yq && apt-get install -y \
      ca-certificates sudo coreutils \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y \
      unminimize \
    && yes | unminimize || true \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends --fix-missing \
      software-properties-common build-essential apt-utils \
    && yes | add-apt-repository main \
    && yes | add-apt-repository universe \
    && yes | add-apt-repository restricted \
    && yes | add-apt-repository multiverse \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends --fix-missing \
      moreutils whiptail procps gzip unzip \
      net-tools iproute2 traceroute inetutils-ping bind9-dnsutils \
      unzip wget curl ssh calc xxd gpg less rlwrap socat netcat-openbsd strace tcpdump \
      file tree highlight lsof \
      openssl openssh-server libssl-dev sshpass \
      bash-completion \
      man locales locate \
      rsync \
      vim-gtk3 \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends --fix-missing \
      gcc clang clang-format ccache gdb-multiarch \
      exuberant-ctags cscope \
      cmake ninja-build pkg-config \
      manpages-dev manpages-posix-dev \
      libboost-all-dev \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends --fix-missing \
      git tig quilt \
      gawk silversearcher-ag tmux \
      pv at cmatrix mc grc vlock jq expect colordiff bsdmainutils htop \
      bat entr xclip xsel ack psmisc fd-find bfs \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends \
      python3 python3-pip \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends \
      nodejs \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update -yq && apt-get install -y --no-install-recommends \
      openssh-server \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

RUN echo "root:$ROOT_PWD" | chpasswd -e

RUN sed -i '/:'"$GID"':/d' /etc/group
RUN groupadd -g $GID -o $UNAME
RUN groupadd sudo || true
RUN userdel ubuntu || true
RUN useradd -m -u $UID -g $GID -G sudo,adm -o -s /bin/bash $UNAME
RUN echo "$UNAME:$USER_PWD" | chpasswd -e

RUN sed -i '/@includedir/i '"$UNAME"'	ALL=(ALL:ALL) ALL' /etc/sudoers

RUN mv /usr/bin/hostname /usr/bin/hostname.bck \
    && echo "echo ubu" >/usr/bin/hostname \
    && chmod a+rx /usr/bin/hostname

RUN mkdir -p /etc/ssh/sshd_config.d \
    && echo "Port 4022" >>/etc/ssh/sshd_config.d/port.conf

RUN locale-gen C.UTF-8 en_US.UTF-8 en_GB.UTF-8 pl_PL.UTF-8 \
    && sudo update-locale \
        LANGUAGE="en" \
        LANG="en_US.UTF-8" LC_CTYPE="en_US.UTF-8" LC_MESSAGES="en_US.UTF-8" \
        LC_TIME="en_GB.UTF-8" \
        LC_ADDRESS="pl_PL.UTF-8" LC_IDENTIFICATION="pl_PL.UTF-8" LC_MEASUREMENT="pl_PL.UTF-8" LC_MONETARY="pl_PL.UTF-8" LC_NAME="pl_PL.UTF-8" LC_NUMERIC="pl_PL.UTF-8" LC_PAPER="pl_PL.UTF-8" LC_TELEPHONE="pl_PL.UTF-8" \
        LC_COLLATE="C" \
        LC_ALL=

RUN echo "tzdata tzdata/Areas select Europe" > /tmp/preseed.cfg \
    && echo "tzdata tzdata/Zones/Europe select Warsaw" >> /tmp/preseed.cfg \
    && debconf-set-selections /tmp/preseed.cfg \
    && rm -f /etc/timezone /etc/localtime /tmp/preseed.cfg \
    && apt-get update -yq && apt-get install -y --no-install-recommends \
      tzdata \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

COPY alacritty.info /tmp
RUN tic -xe alacritty,alacritty-direct /tmp/alacritty.info \
    && rm /tmp/alacritty.info

# ------------------

USER $UNAME
