<div align="center">

# asdf-go-sdk [![Build](https://github.com/yacchi/asdf-go-sdk/actions/workflows/build.yml/badge.svg)](https://github.com/yacchi/asdf-go-sdk/actions/workflows/build.yml) [![Lint](https://github.com/yacchi/asdf-go-sdk/actions/workflows/lint.yml/badge.svg)](https://github.com/yacchi/asdf-go-sdk/actions/workflows/lint.yml)


[go-sdk](https://github.com/yacchi/asdf-go-sdk) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Why?](#why)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

- `bash`, `curl`, `tar`: generic POSIX utilities.
- `SOME_ENV_VAR`: set this environment variable in your shell config to load the correct version of tool x.

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
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/yacchi/asdf-go-sdk/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [Yasunori Fujie](https://github.com/yacchi/)
