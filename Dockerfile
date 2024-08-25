FROM ubuntu:24.04

ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive

# Install locale
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
RUN apt-get update && apt-get install -y --no-install-recommends \
  locales && \
  echo "$LANG UTF-8" >> /etc/locale.gen && \
  locale-gen && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# Unminimize to include man pages
RUN yes | unminimize

# Install systemd
RUN apt-get update && apt-get install -y \
  dbus dbus-x11 systemd && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  dpkg-divert --local --rename --add /sbin/udevadm && \
  ln -s /bin/true /sbin/udevadm
# Workaround for systemd-sysusers.service https://github.com/arkane-systems/genie/issues/190#issuecomment-938019970
RUN mkdir -p /etc/systemd/system/systemd-sysusers.service.d && \
  echo "[Service]" >> /etc/systemd/system/systemd-sysusers.service.d/override.conf && \
  echo "LoadCredential=" >> /etc/systemd/system/systemd-sysusers.service.d/override.conf
RUN systemctl disable systemd-resolved
VOLUME ["/sys/fs/cgroup"]
STOPSIGNAL SIGRTMIN+3
# TODO entrypoint.sh script -> create config file based on ENV variables
CMD [ "/sbin/init" ]

# Install GNOME
# NOTE if you want plain gnome, use: "apt-get install -y --no-install-recommends gnome-session gnome-terminal"
# NOTE initial setup uninstalled as disabling via /etc/gdm3/custom.conf stopped working: https://askubuntu.com/q/1028822/206608
RUN apt-get update \
  && apt-get install -y ubuntu-desktop fcitx-config-gtk gnome-tweaks gnome-usage \
  && apt-get purge -y --autoremove gnome-initial-setup \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Remove failing system services
RUN rm -f \
  /lib/systemd/system/colord.service \
  /lib/systemd/system/geoclue.service \
  # TODO requires CAP_SYS_ADMIN
  # /lib/systemd/system/polkit.service \
  /lib/systemd/system/rtkit-daemon.service \
  /lib/systemd/system/upower.service \
  /lib/systemd/system/systemd-resolved.service
# Remove user services
# NOTE we manually enable the ones we want via `systemctl enable` later
RUN rm -f \
  /etc/systemd/system/*.wants/*
# Disable screen lock: https://superuser.com/a/1469489
# BUG: https://askubuntu.com/q/1511958/206608
RUN \
  gsettings set org.gnome.desktop.lockdown disable-lock-screen true && \
  gsettings set org.gnome.desktop.screensaver lock-enabled false && \
  gsettings set org.gnome.desktop.screensaver idle-activation-enabled false

# Install TigerVNC server
# TODO set VNC port in service file > exec command
# TODO check if it works with default config file
# NOTE tigervnc because of XKB extension: https://github.com/i3/i3/issues/1983
RUN apt-get update \
  && apt-get install -y tigervnc-common tigervnc-scraping-server tigervnc-standalone-server tigervnc-viewer tigervnc-xorg-extension \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
# Disable VNC config window
RUN sed -i 's/iconic/nowin/' /etc/X11/Xtigervnc-session
# TODO specify options like geometry as environment variables -> source variables in service via EnvironmentFile=/path/to/env
# NOTE logout will stop tigervnc service -> need to manually start (gdm for graphical login is not working)
# TODO use ARG ${USER}
# Note port 5900 + display number (e.g. ":1") = 5901, unprivileged user "ubuntu" created later
RUN echo ":1=ubuntu" >> /etc/tigervnc/vncserver.users
RUN systemctl enable tigervncserver@:1.service
EXPOSE 5901

# Install noVNC
RUN apt-get update && apt-get install -y \
  novnc \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*
RUN ln -s /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html
# Set hostname printed to output
RUN sed -i 's/$(hostname)/localhost/g' /usr/share/novnc/utils/novnc_proxy
# TODO specify options like ports as environment variables -> source variables in service via EnvironmentFile=/path/to/env
COPY novnc.service /etc/systemd/system/novnc.service
RUN systemctl enable novnc
EXPOSE 6901

# Set up unprivileged user
# NOTE user hardcoded in /etc/tigervnc/vncserver.users
# NOTE alternative is to use libnss_switch and create user at runtime -> use entrypoint script
ARG USER=ubuntu
RUN apt-get update && apt-get install -y sudo && apt-get clean && rm -rf /var/lib/apt/lists/* && \
  echo "${USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${USER}" && \
  chmod 440 "/etc/sudoers.d/${USER}"
USER "${USER}"
ENV USER="${USER}" \
  HOME="/home/${USER}"
WORKDIR "/home/${USER}"

# Set up VNC
RUN mkdir -p $HOME/.vnc
# TODO Wayland support
RUN echo "session=ubuntu-xorg" >> $HOME/.vnc/config
RUN echo "localhost=no" >> $HOME/.vnc/config
RUN echo "geometry=1280x720" >> $HOME/.vnc/config
RUN echo "acoman" | vncpasswd -f >> $HOME/.vnc/passwd && chmod 600 $HOME/.vnc/passwd

# switch back to root to start systemd
USER root
