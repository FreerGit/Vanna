# #!/bin/bash

dune build
BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
  if [[ "$(uname -o)" == "GNU/Linux" ]]; then
    tmux new-session -d -s my_session "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 2"
    tmux split-window -h "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 1"
    tmux split-window -v "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 0"
    tmux select-layout tiled
    set -g mouse on
    tmux attach -t my_session
    
  # Create a new screen session
  else
    # Windows (assumes Windows Terminal is available)
    wt.exe \
    wsl bash -c "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 0" \; \
    split-pane wsl bash -c "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 1" \; \
    split-pane wsl bash -c "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 2"
  fi
fi