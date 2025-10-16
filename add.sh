#!/bin/bash

sudo adduser administrador
sudo usermod -aG sudo administrador
sudo groupadd -f infrawatch
sudo usermod -aG infrawatch administrador
sudo mkdir -p /home/infrawatch
sudo chown -R administrador:infrawatch /home/infrawatch
sudo chmod -R 770 /home/infrawatch