# {{ app_name }}

## Building and Installation

You'll need the following dependencies:
* glib-2.0
* gobject-2.0
* granite
* gtk+-3.0
* libhandy-1-dev
* meson
* valac

Run `meson build` to configure the build environment. Change to the build directory and run `ninja` to build

```bash
meson build --prefix=/usr
cd build
ninja
```

To install, use `ninja install`, then execute with `com.github.{{ github_username }}.{{ github_repository }}`

```bash
ninja install
com.github.{{ github_username }}.{{ github_repository }}
```
