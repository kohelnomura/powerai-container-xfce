FROM nvidia/cuda-ppc64le:8.0-cudnn7-runtime-ubuntu16.04
MAINTAINER kohhei Nomura <kohei1@jp.ibm.com>

# install base
RUN apt-get update && \
    apt-get install -y wget curl git apt-transport-https apt-utils && \
    apt-get clean

# install PowerAI
RUN cd /tmp && \
    wget https://public.dhe.ibm.com/software/server/POWER/Linux/mldl/ubuntu/mldl-repo-network_4.0.0_ppc64el.deb && \
    dpkg -i mldl-repo-network_4.0.0_ppc64el.deb && \
    rm mldl-repo-network_4.0.0_ppc64el.deb
RUN apt-get update && \
    apt-get install -y power-mldl && \
    apt-get clean

# install utils
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    vim htop tree screen unzip firefox \
    openssh-server \
    ubuntu-desktop gnome-core gdm gnome-panel gnome-settings-daemon metacity nautilus gnome-terminal \
    iputils-ping net-tools \
    language-pack-ja-base language-pack-ja fonts-ipafont-mincho && \
    apt-get clean

# install vncserver
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    x11vnc xfce4 xvfb fonts-ipaexfont && \
    apt-get clean

# install python modules
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python-opencv && \
    apt-get clean

# copy base files
COPY root /
COPY password.txt .

# setup ssh
RUN mkdir /var/run/sshd
RUN echo root:$(cat password.txt) | chpasswd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i '/^AcceptEnv/s/^/#/' /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN echo "export PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH" >> /root/.bashrc && \
    echo "export LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64" >> /root/.bashrc

# setup vnc
RUN  x11vnc -storepasswd $(cat password.txt) /root/.vnc/passwd && rm password.txt

# setup timezone and locale
ENV TZ=Asia/Tokyo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN echo "export LANG=ja_JP.UTF-8" >> /root/.bashrc
RUN echo "export LANGUAGE=ja_JP.UTF-8" >> /root/.bashrc
ENV LANGUAGE=ja_JP
ENV LANG=ja_JP.UTF-8

# import python modules
RUN pip install IPython==5.3

ENTRYPOINT ["/usr/bin/s6-svscan","/etc/s6"]
CMD []
