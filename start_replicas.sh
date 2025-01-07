#!/bin/bash

cargo build
BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
  if [[ "$(uname -o)" == "GNU/Linux" ]]; then
    tmux new-session -s my_session -d "source ~/.profile && cd ~/dev/vanna && ./target/debug/cli run-replica --addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 --replica 2"
    tmux split-window -h "source ~/.profile && cd ~/dev/vanna && ./target/debug/cli run-replica --addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 --replica 1"
    tmux split-window -v "source ~/.profile && cd ~/dev/vanna && ./target/debug/cli run-replica --addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 --replica 0"
    
    tmux select-layout tiled
    tmux set-option -g mouse on
    tmux attach -t my_session
  else
    wt.exe \
    wsl bash -c "source ~/.profile && cd ~/dev/vanna && cargo run -- run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 0" \; \
    split-pane wsl bash -c "source ~/.profile && cd ~/dev/vanna && cargo run -- run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 1" \; \
    split-pane wsl bash -c "source ~/.profile && cd ~/dev/vanna && cargo run -- run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 2"
  fi
fi
