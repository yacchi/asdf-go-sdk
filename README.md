# asdf-go-sdk [![Build](https://github.com/yacchi/asdf-go-sdk/actions/workflows/build.yml/badge.svg)](https://github.com/yacchi/asdf-go-sdk/actions/workflows/build.yml) [![Lint](https://github.com/yacchi/asdf-go-sdk/actions/workflows/lint.yml/badge.svg)](https://github.com/yacchi/asdf-go-sdk/actions/workflows/lint.yml)

[Go](https://golang.org/) plugin for the [asdf version manager](https://asdf-vm.com).

This plugin is based on the official installation method
of [installing multiple go versions][official installation method].

Since development environments such as Visual Studio Code and JetBrains IDEs (e.g. GoLand, IntelliJ) are the same way to
install Go SDK, you can work smoothly with these development environments.

**However, it is recommended to use the latest version of Go unless there is a specific reason not to.**

# Why?

Environments installed with asdf are usually stored in `ASDF_DATA_DIR/installs/{PLUGIN_NAME}`.

For the Go language, it is usually installed under `HOME/sdk` if you use the [official installation method]. Also, some
development environments (e.g., [VSCode][VSCode Manage Go Version] and [JetBrains IDEs][JetBrains Manage Go Versions])
are installed in the same location.

Therefore, if you follow asdf's method, you will have to maintain the Go environment twice.

This plugin adds the Go SDK to `HOME/sdk` using Go installed on the system, and provides only the functions used by
asdf.

It does not support other GOPATH management or environments where Go is not installed on the system, so if you need
those, please use other methods (e.g. [asdf-golang]).

# Important Update

There has been a breaking change in the repository used by
the [installing multiple go versions][official installation method].
As a result, regardless of whether you use this plugin or not, the official method is no longer available for Go
versions prior to 1.18.

To work around this issue, this plugin now directly downloads the SDK and extracts it using the same approach as the
official method,
ensuring compatibility with older Go versions.

# Dependencies

- git
- coreutils
- curl or wget

# Install

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to install & manage versions.

## for asdf

```shell
# Install plugin
asdf plugin add go-sdk
# or
asdf plugin add go-sdk https://github.com/yacchi/asdf-go-sdk.git

# Show all installable versions
asdf list all go-sdk

# Install specific version
asdf install go-sdk latest

# Set a version globally (on your ~/.tool-versions file)
asdf set --home go-sdk latest

# Now go-sdk commands are available
go version

# If you have installed or uninstalled go sdk without using asdf,
# you can use the following command to make asdf recognize it.
asdf cmd go-sdk sync.bash
```

## for mise

```shell
# Install plugin
mise plugins install go-sdk
# or
mise plugins install go-sdk https://github.com/yacchi/asdf-go-sdk.git

# Show all installable versions
mise ls-remote go-sdk

# Install specific version
mise install go-sdk@latest

# Set a version globally
mise use --global go-sdk@latest

# Now go-sdk commands are available
go version

# Currently mise cannot execute asdf plugin commands, so please execute the commands directly.
ASDF_DIR=~/.local/share/mise $ASDF_DIR/plugins/go-sdk/lib/commands/command-sync.bash
```

## for asdf (legacy bash)

```shell
# Install plugin
asdf plugin add go-sdk
# or
asdf plugin add go-sdk https://github.com/yacchi/asdf-go-sdk.git

# Show all installable versions
asdf list-all go-sdk

# Install specific version
asdf install go-sdk latest

# Set a version globally (on your ~/.tool-versions file)
asdf global go-sdk latest

# Now go-sdk commands are available
go version

# If you have installed or uninstalled go sdk without using asdf,
# you can use the following command to make asdf recognize it.
asdf go-sdk sync
```

# Configuration

## Environment variables

- GO_SDK_PATH - the directory where the Go SDK will be installed (default is $HOME/sdk)
- GO_SDK_LOW_LIMIT_VERSION - the lower limit of the version displayed by list-all (default is 1.12.0)

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/yacchi/asdf-go-sdk/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [Yasunori Fujie](https://github.com/yacchi/)

[official installation method]:https://golang.org/doc/manage-install#installing-multiple

[asdf-golang]:https://github.com/asdf-community/asdf-golang

[VSCode Manage Go Version]: https://github.com/golang/vscode-go/blob/master/docs/ui.md#managing-your-go-version

[JetBrains Manage Go Versions]: https://www.jetbrains.com/help/go/configuring-goroot-and-gopath.html#download-go-sdk
