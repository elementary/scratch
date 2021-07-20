conf_data = configuration_data()
conf_data.set_quoted('PROJECT_NAME', meson.project_name())
conf_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf_data.set_quoted('VERSION', meson.project_version())
conf_data.set_quoted('PREFIX', get_option('prefix'))
conf_data.set_quoted('PLUGINDIR', pluginsdir)
conf_data.set_quoted('DATADIR', join_paths (get_option('prefix'), get_option('datadir')))
config_header = configure_file(
    input : 'config.vala.in',
    output : 'config.vala',
    configuration : conf_data
)

code_files = files(
    'Application.vala',
    'MainWindow.vala',
    'Utils.vala',
    'Dialogs/PreferencesDialog.vala',
    'Dialogs/RestoreConfirmationDialog.vala',
    'Dialogs/GlobalSearchDialog.vala',
    'Dialogs/NewBranchDialog.vala',
    'FolderManager/ContractMenuItem.vala',
    'FolderManager/File.vala',
    'FolderManager/FileItem.vala',
    'FolderManager/FileView.vala',
    'FolderManager/FolderItem.vala',
    'FolderManager/Item.vala',
    'FolderManager/ProjectFolderItem.vala',
    'Services/AppTemplate.vala',
    'Services/CommentToggler.vala',
    'Services/Document.vala',
    'Services/FileHandler.vala',
    'Services/GitManager.vala',
    'Services/MonitoredRepository.vala',
    'Services/PluginManager.vala',
    'Services/Settings.vala',
    'Services/TemplateManager.vala',
    'Widgets/ChooseProjectButton.vala',
    'Widgets/DocumentView.vala',
    'Widgets/FormatBar.vala',
    'Widgets/SourceGutterRenderer.vala',
    'Widgets/HeaderBar.vala',
    'Widgets/NewAppDialog.vala',
    'Widgets/Sidebar.vala',
    'Widgets/PaneSwitcher.vala',
    'Widgets/SearchBar.vala',
    'Widgets/SourceView.vala',
    'Widgets/WelcomeView.vala',
)

executable(
    meson.project_name(),
    code_files,
    code_resources,
    config_header,
    dependencies: dependencies,
    install: true
)

codecore = library(
    'codecore',
    code_files,
    config_header,
    dependencies: dependencies,
    install: true,
    install_dir: [true, true, true],
    version: '0.0'
)

pkg = import('pkgconfig')

pkg.generate(
    version: '0.1',
    libraries: codecore,
    description: 'elementary Code headers',
    name: 'codecore',
    filebase: 'codecore'
)

install_data ('codecore.deps', install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'vala', 'vapi'))

codecore_dep = declare_dependency(
    link_with: codecore,
    dependencies: dependencies,
    include_directories: [include_directories('.')]
)
