#!/bin/zsh
# Add the code below to /home/$USER/.bashrc
if [[ $- != *i* ]] ; then
  # Shell is non-interactive.  Be done now!
  return
fi

exec /usr/bin/zsh