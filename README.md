# Scaffold

[![Package Version](https://img.shields.io/hexpm/v/scaffold_gleam)](https://hex.pm/packages/scaffold_gleam)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/scaffold_gleam/)

## Installation

Clone the repo
```sh
git clone git@github.com:codemonkey76/scaffold_gleam
```

Compile the program into an executable
```sh
cd scaffold_gleam
gleam run -m gleescript
```

Move to somewhere in your path, e.g. `/usr/local/bin`
```sh
sudo mv scaffold_gleam /usr/local/bin/scaffold
```

## Running the app

Start a new gleam repo

```sh
gleam new my_application
```

Configure as javascript target

Edit your gleam.toml and add `target = "javascript"`

Create the scaffolding, run from the root of your new project

```sh
scaffold
```

Further documentation can be found at <https://hexdocs.pm/scaffold_gleam>.
