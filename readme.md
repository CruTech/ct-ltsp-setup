# Crütech LTSP server setup scripts #

# Instructions

Current version targets Ubuntu 18 LTS versions.
An internet connection is required for installations of packages.
While configuration of network interfaces is supported an initial configuration is required to begin `env-init.sh`, DHCP is acceptable.

```
sudo su
bin/env-init.sh && bin/ltsp-setup.pl && configure-network.pl && reboot
```