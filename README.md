# asdf-go-sdk [![Build](https://github.com/yacchi/asdf-go-sdk/actions/workflows/build.yml/badge.svg)](https://github.com/yacchi/asdf-go-sdk/actions/workflows/build.yml) [![Lint](https://github.com/yacchi/asdf-go-sdk/actions/workflows/lint.yml/badge.svg)](https://github.com/yacchi/asdf-go-sdk/actions/workflows/lint.yml)

[Go](https://golang.org/) plugin for the [asdf version manager](https://asdf-vm.com).

This plugin is based on the official method of [installing multiple go versions](https://golang.org/doc/manage-install#installing-multiple).

Since development environments such as Visual Studio Code and JetBrains IDEs (ex. GoLand, IntelliJ) are
the same way to install Go SDK, you can work smoothly with these development environments.

**However, it is recommended to use the latest version of Go unless there is a specific reason not to.**

# Dependencies
- Requires go version 1.12 or higher of `go`
- git

# Install

Plugin:

```shell
asdf plugin add go-sdk
# or
asdf plugin add go-sdk https://github.com/yacchi/asdf-go-sdk.git
```

go-sdk:

```shell
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

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/yacchi/asdf-go-sdk/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [Yasunori Fujie](https://github.com/yacchi/)
