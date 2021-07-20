icon_sizes = ['16', '24', '32', '48', '64', '128']

foreach i : icon_sizes
    install_data(
        join_paths('icons', i, meson.project_name() + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps')
    )
    install_data(
        join_paths('icons', i, meson.project_name() + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i + '@2', 'apps')
    )
endforeach

install_data([
  'fonts/BuilderBlocks.ttf',
], install_dir: join_paths(get_option('datadir'), meson.project_name(), 'fonts'))

install_subdir([
  'templates',
], install_dir: join_paths(get_option('datadir'), meson.project_name()))

install_data(
    'io.elementary.code.gschema.xml',
    'io.elementary.code.plugins.spell.gschema.xml',
    'io.elementary.code.plugins.terminal.gschema.xml',
    install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'glib-2.0', 'schemas')
)

config_data = configuration_data()
config_data.set('EXEC_NAME', meson.project_name())

# Set the executable name and translate the desktop files
desktop_in_file = configure_file(
    input: 'io.elementary.code.desktop.in.in',
    output: '@BASENAME@',
    configuration: config_data
)

desktop_file = i18n.merge_file(
    input: desktop_in_file,
    output: 'io.elementary.code.desktop',
    po_dir: join_paths(meson.source_root (), 'po', 'extra'),
    type: 'desktop',
    install_dir: join_paths(get_option('datadir'), 'applications'),
    install: true
)

# Translate the AppData file
appstream_file = i18n.merge_file(
    input: 'io.elementary.code.appdata.xml.in',
    output: '@BASENAME@',
    po_dir: join_paths(meson.source_root (), 'po', 'extra'),
    install_dir: join_paths(get_option('datadir'), 'metainfo'),
    install: true
)

config_data = configuration_data()
config_data.set('install_prefix', get_option('prefix'))
config_data.set('bin_dir', get_option('bindir'))
config_data.set('exec_name', meson.project_name())

if get_option ('have_pkexec')
    policy_in = configure_file(
        input: 'code.policy.in.in',
        output:  meson.project_name() + '.policy.in',
        configuration: config_data,
        install: false,
    )

    i18n.merge_file(
        'policy',
        input: policy_in,
        output: meson.project_name() + '.policy',
        po_dir: join_paths(meson.source_root (), 'po', 'extra'),
        install: true,
        install_dir: join_paths(get_option('datadir'), 'polkit-1', 'actions'),
    )
endif
