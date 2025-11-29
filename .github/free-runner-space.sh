#!/usr/bin/env bash

# For a List of pre-installed packages on the runner image see
# https://github.com/actions/runner-images/tree/main?tab=readme-ov-file#available-images

echo "Disk space before cleanup"
df -h

# Remove packages not required to run the Gluon build CI
sudo apt-get -y remove \
	dotnet-* \
	firefox \
	google-chrome-stable \
	kubectl \
	microsoft-edge-stable \
	mono-complete \
	powershell \
	temurin-*-jdk

# Remove Android SDK tools
sudo rm -rf /usr/local/lib/android

# Remove powershell
sudo rm -rf /usr/local/share/powershell

# Remove CodeQL cache
sudo rm -rf /opt/hostedtoolcache/CodeQL

# remove dotnet
sudo rm -rf /usr/share/dotnet

# remove swift
sudo rm -rf /usr/share/swift

# remove ghcup (Haskell)
sudo rm -rf /usr/local/.ghcup

# remove no longer needed dependencies
sudo apt-get autoremove

echo "Disk space after cleanup"
df -h
