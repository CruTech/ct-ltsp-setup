#! /usr/bin/env bash

apt update
apt -y install build-essential curl unzip

curl -L https://cpanmin.us | perl - App::cpanminus

curl .../server-setup-0.1.0.zip

unzip server-setup-0.1.0.zip

cd server-setup

cpanm --installdeps .

sudo su
bin/ltsp-setup.pl && configure-network.pl && reboot