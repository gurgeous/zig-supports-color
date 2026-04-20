default:
  just --list

build: (_zig "-Doptimize=Debug")
build-release: (_zig "-Doptimize=ReleaseSmall")
build-windows: (_zig "-Dtarget=x86_64-windows-gnu")

_zig +ARGS:
  # REMIND: add --pkg-dir when possible
  zig build -p tmp/zig-out --cache-dir tmp/zig-cache {{ARGS}}

clean:
  rm -rf tmp
  mkdir tmp

#
# check/ci
#

check: build lint test
  just banner "✓ check ✓"

[unix]
ci: check run
[windows]
ci: build test run
# note ^^ - fmt fails on windows for some reason, so

llm: fmt
  LLM=1 just check

#
# dev
#

fmt: (_fmt)
  just banner "✓ fmt ✓"

lint: (_fmt "--check")
  just banner "✓ lint ✓"

_fmt *ARGS:
  zig fmt {{ARGS}} *.zig

run *ARGS: build-release
  tmp/zig-out/bin/zig-supports-color {{ARGS}}

test:
  if [ -n "${LLM:-}" ]; then just _zig test ; else just _zig test --summary all ; fi
  just banner "✓ test ✓"

test-watch:
  watchexec --clear=clear --stop-timeout=0 just test

#
# banner
#

set quiet

banner +ARGS:  (_banner '\e[48;2;064;160;043m' ARGS)
warning +ARGS: (_banner '\e[48;2;251;100;011m' ARGS)
fatal +ARGS:   (_banner '\e[48;2;210;015;057m' ARGS)
  exit 1
_banner BG +ARGS:
  if [ -z "${LLM:-}" ]; then \
    printf '\e[38;5;231m{{BOLD+BG}}[%s] %-72s {{NORMAL}}\n' "$(date +%H:%M:%S)" "{{ARGS}}" ; \
  fi
