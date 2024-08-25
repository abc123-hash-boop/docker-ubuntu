## Ubuntu Desktop (GNOME) Dockerfile


This repository contains the *Dockerfile* and *associated files* for setting up a container with Ubuntu, GNOME and TigerVNC for [Docker](https://www.docker.io/).

* The VNC Server currently defaults to 1366*768 24bit.

### Dependencies

* [ubuntu:19.04](https://hub.docker.com/_/ubuntu)


### Installation

1. Install [Docker](https://www.docker.io/).

	For an Ubuntu 18.04 host the following commands will get you up and running:

	`#install docker-ce from Docker official site step by step`


2. You can then pull the file:

	`sudo docker pull darkdragon-001/dockerfile-ubuntu-gnome`


	Or alternatively build an image from the Dockerfile:

	`sudo docker build -t="darkdragon-001/dockerfile-ubuntu-gnome" github.com/darkdragon-001/Dockerfile-Ubuntu-Gnome`


### Usage

#### Starting

* Change the port number to run multiple instances on the same host (remeber to open the ports for tcp ingress)

* this will run and drop you into a session:

	`sudo docker run -it --rm -p 5901:5901 darkdragon-001/dockerfile-ubuntu-gnome`

* or for silent running:

	`sudo docker run -it -d -p 5901:5901 darkdragon-001/dockerfile-ubuntu-gnome`

#### Connecting to instance

* Connect to `vnc://<host>:5901` via your VNC client. currently the password is hardcoded to "acoman"

#### Notes

* You can use the following command from within the container to kill the vnc server:

	`USER=root vncserver -kill :1`

* Then run the following command from within the container to restart start the vnc server, the flags are optional but pretty self explanatory.

	`USER=root vncserver :1 -geometry 1024x768 -depth 24`

