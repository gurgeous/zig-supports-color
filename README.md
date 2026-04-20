[![test](https://github.com/gurgeous/zig-supports-color/actions/workflows/ci.yml/badge.svg)](https://github.com/gurgeous/zig-supports-color/actions/workflows/ci.yml)

# zig-supports-color

A small, zero-allocation library that detects ANSI color support in the terminal. Built on Zig 0.16.

### Usage

```zig
//
// Returns:
//
// .none    - no support for color
// .ansi    - basic 16 color palette (often customized)
// .ansi256 - standard 256 color palette
// .ansi16m - 16m rgb ("truecolor"), the modern standard
//

// look at env
const level = supports_color.onEnv(init.environ_map);

// or try stdout, stderr, dev/tty. checks if the file is a tty
const level = try supports_color.onStdout(init.io, init.environ_map);
const level = try supports_color.onStderr(init.io, init.environ_map);
const level = try supports_color.onDevTty(init.io, init.environ_map);
```

### Installation

```sh
# fetch and add to build.zig.zon
zig fetch --save git+https://github.com/gurgeous/zig-supports-color.git
```

Edit your `build.zig`:

```zig
const dep = b.dependency("supports_color", .{ .target = target, .optimize = optimize });
main.root_module.addImport("supports_color", dep.module("supports_color"));
```

### Details

We rely primarily on $TERM and $COLORTERM, and honor $NO_COLOR/$FORCE_COLOR if truthy. We look at $CI and friends as well. This is [surprisingly complicated](https://github.com/gurgeous/zig-supports-color/blob/main/supports_color.zig).

Special thanks to these libraries which provided the basis for `zig-supports-color`. My work is essentially a zig-friendly variant of these, with some effort made to remove outdated heuristics:

- [BurntSushi/termcolor](https://github.com/BurntSushi/termcolor) (rust)
- [chalk/supports-color](https://github.com/chalk/supports-color) (ts)
- [charmbracelet/colorprofile](https://github.com/charmbracelet/colorprofile) (go)
- [crossterm-rs/crossterm](https://github.com/crossterm-rs/crossterm) (rust)
- [muesli/termenv](https://github.com/muesli/termenv) (go)
- [rust-cli/anstyle](https://github.com/rust-cli/anstyle) (rust)

Also see this delightful ncurses terminfo doc:

- https://invisible-island.net/ncurses/terminfo.src.html

### Changelog

**0.1.0 (unreleased)**

- initial announcement

### Future Work

I will be using this in my cli projects, though I consider it beta quality. In particular [tennis][https://github.com/gurgeous/tennis], which people want to use on older terminals that don't support 16m. Feel free to create issues/PRs, feedback always welcome.
