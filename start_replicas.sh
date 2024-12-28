# #!/bin/bash

dune build

if [[ "$(uname -o)" == "GNU/Linux" ]]; then
  tmux new-session -d -s my_session "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 2"
  tmux split-window -h "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 1"
  tmux split-window -v "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 0"
  tmux select-layout tiled
  tmux attach -t my_session
else
  # Windows (assumes Windows Terminal is available)
  wt.exe \
  wsl bash -c "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 0" \; \
  split-pane wsl bash -c "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 1" \; \
  split-pane wsl bash -c "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 2"
fi