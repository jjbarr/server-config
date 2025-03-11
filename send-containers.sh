#!/bin/bash
ssh ptnote mkdir -p "~/.config/containers/systemd"
rsync -av containers/* ptnote:~/.config/containers/systemd
rsync -av units/* ptnote:~/.config/systemd/user
ssh ptnote systemctl --user daemon-reload

