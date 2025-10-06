#!/usr/bin/env bash

# https://elixir-lang.org/install.html#install-scripts

# brew installs elixir compiled with otp 28 but shipped with otp 27, which is wrong

curl -fsSO https://elixir-lang.org/install.sh
sh install.sh elixir@1.18.4 otp@27.3.4
installs_dir=$HOME/.elixir-install/installs
export PATH=$installs_dir/otp/27.3.4/bin:$PATH
export PATH=$installs_dir/elixir/1.18.4-otp-27/bin:$PATH
elixir --version
rm -rf install.sh
