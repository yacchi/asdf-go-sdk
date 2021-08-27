FROM ubuntu:20.04

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y bash git curl && \
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.8.1 && \
    echo '. $HOME/.asdf/asdf.sh' >> $HOME/.bashrc && \
    echo '. $HOME/.asdf/completions/asdf.bash' >> $HOME/.bashrc

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y golang

WORKDIR /root
