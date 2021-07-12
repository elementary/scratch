module_name = 'gvls-code'

gvls_plugin_sources = files([
    'gvls-code-plugin.vala'
    ])

gvls_install_dir=join_paths(pluginsdir, module_name)

install_data('gvls-code.plugin', install_dir: gvls_install_dir)

plugin_deps = [
    gvls_dep,
    gvlsp_dep,
    gvlsui_dep,
    codecore_dep,
    ]

shared_module(module_name, gvls_plugin_sources,
    dependencies: plugin_deps,
    install: true,
    install_dir: gvls_install_dir,
    vala_args: [
        '--target-glib=2.52',
    ]
)

custom_target(module_name + '.plugin_merge',
    input: module_name + '.plugin',
    output: module_name + '.plugin',
    command : [msgfmt,
               '--desktop',
               '--keyword=Description',
               '--keyword=Name',
               '-d' + join_paths(meson.source_root (), 'po', 'plugins'),
               '--template=@INPUT@',
               '-o@OUTPUT@',
               ],
    install : true,
    install_dir: join_paths(pluginsdir, module_name),
)
