project(
    'io.elementary.code',
    'vala', 'c',
    version: '6.0.0'
)

add_project_arguments([
        '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name())
    ],
    language: 'c',
)

add_project_arguments(
    ['--vapidir', join_paths(meson.current_source_dir(), 'vapi')],
    language: 'vala'
)

if get_option('have_pkexec')
    add_project_arguments('--define=HAVE_PKEXEC', language: 'vala')
endif

libexecdir = join_paths(get_option('prefix'), get_option('libexecdir'), meson.project_name())
pluginsdir = join_paths(get_option('prefix'), get_option('libdir'), meson.project_name(), 'plugins')

gnome = import('gnome')
i18n = import('i18n')

glib_dep = dependency('glib-2.0', version: '>=2.30.0')
gio_unix_dep = dependency('gio-unix-2.0', version: '>=2.20')
gee_dep = dependency('gee-0.8', version: '>=0.8.5')
gtk_dep = dependency('gtk+-3.0', version: '>=3.6.0')
granite_dep = dependency('granite', version: '>=6.0.0')
handy_dep = dependency('libhandy-1', version: '>=0.90.0')
libportal_dep = dependency ('libportal')
gtksourceview_dep = dependency('gtksourceview-4')
peas_dep = dependency('libpeas-1.0')
peasgtk_dep = dependency('libpeas-gtk-1.0')
git_dep = dependency('libgit2-glib-1.0')
fontconfig_dep = dependency('fontconfig')
pangofc_dep = dependency('pangoft2')
posix_dep = meson.get_compiler('vala').find_library('posix')

code_resources = gnome.compile_resources(
    'code-resources', 'data/' + meson.project_name() + '.gresource.xml',
    source_dir: 'data'
)

dependencies = [
    glib_dep,
    gio_unix_dep,
    gee_dep,
    gtk_dep,
    granite_dep,
    handy_dep,
    libportal_dep,
    gtksourceview_dep,
    peas_dep,
    peasgtk_dep,
    git_dep,
    fontconfig_dep,
    pangofc_dep,
    posix_dep,
]

subdir('data')
subdir('src')
if get_option('plugins')
    subdir('plugins')
endif
subdir('po')

meson.add_install_script('meson/post_install.py')
