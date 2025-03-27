FROM ubuntu:24.04

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y bash git curl golang

RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.15.0 && \
    echo '. $HOME/.asdf/asdf.sh' >> $HOME/.bashrc && \
    echo '. $HOME/.asdf/completions/asdf.bash' >> $HOME/.bashrc

RUN mkdir -p ~/.asdf/plugins/go-sdk

RUN curl https://mise.run | sh && \
    echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc && \
    mkdir -p ~/.local/share/mise/plugins && \
    ln -sf ~/.asdf/plugins/go-sdk ~/.local/share/mise/plugins

RUN go install github.com/asdf-vm/asdf/cmd/asdf@latest

WORKDIR /root
