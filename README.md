# Code
[![Translation status](https://l10n.elementary.io/widgets/code/-/svg-badge.svg)](https://l10n.elementary.io/projects/code/?utm_source=widget)

![Screenshot](data/screenshot.png?raw=true)

## Building, Testing, and Installation

You'll need the following dependencies:
* meson
* libeditorconfig-dev
* libgail-3-dev
* libgee-0.8-dev
* libgit2-glib-1.0-dev
* libgtksourceview-4-dev
* libgtkspell3-3-dev
* libgranite-dev >= 5.2.0
* libhandy-1-dev >= 0.90.0
* libportal-dev
* libpeas-dev
* libsoup2.4-dev
* libvala-0.34-dev (or higher)
* libvte-2.91-dev
* valac

Run `meson build` to configure the build environment. Change to the build directory and run `ninja test` to build

    meson build --prefix=/usr
    cd build
    ninja test

To install, use `ninja install`, then execute with `io.elementary.code`

    sudo ninja install
    io.elementary.code
