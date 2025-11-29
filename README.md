# pipe-while-read

A zsh function that saves me approximately 2-5 seconds every time I use it.

[Obligatory](https://xkcd.com/1319/) [xkcd](https://xkcd.com/1205/).

## Installation

With [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh):

```zsh
cd $ZSH_CUSTOM
git clone https://github.com/pressdarling/pipe-while-read
omz plugin enable pipe-while-read
```

Otherwise, simply source it/add it/copy-and-paste it into your `.zshrc`.

## Rust CLI

A Rust binary is included for standalone use:

```zsh
cargo build
echo -e "foo\nbar" | cargo run -- -n echo "Got:"
echo -e "one\ntwo" | cargo run -- printf "Line:%s\\n"
```

Run the tests with `cargo test`.

## Unlicense

You wouldn't steal a software.

See [The Unlicense](./UNLICENSE)
