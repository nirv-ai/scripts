#!/usr/bin/env bash

# @see https://askubuntu.com/questions/19772/how-to-reinitialize-a-terminal-window-instead-of-closing-it-and-starting-a-new-o
refresh_shell() {
  if [ "$(uname)" = "Darwin" ]; then
    exec /usr/bin/env bash
  else
    exec sudo --login --user "$USER" /bin/sh -c "cd '$PWD'; exec '$SHELL' -l"
  fi
}
