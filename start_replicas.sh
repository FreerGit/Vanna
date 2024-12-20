#!/bin/bash

dune build

wt.exe wsl bash -c "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 0" 
wt.exe wsl bash -c "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 1" 
wt.exe wsl bash -c "source ~/.profile && cd ~/dev/vanna && ./cli.exe run-replica -addresses 127.0.0.1:3000,127.0.0.1:3001,127.0.0.1:3002 -replica 2" 
