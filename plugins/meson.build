msgfmt = find_program('msgfmt')

subdir('brackets-completion')
subdir('detect-indent')
subdir('editorconfig')
subdir('highlight-word-selection')
subdir('markdown-actions')
subdir('outline')
subdir('pastebin')
subdir('preserve-indent')
subdir('spell')
subdir('strip-trailing-save')
subdir('terminal')
subdir('vim-emulation')
subdir('word-completion')

gvls_dep = dependency ('gvls-19', version: '>=19.0', required: false)
gvlsp_dep = dependency ('gvlsp-19', version: '>=19.0', required: false)
gvlsui_dep = dependency ('gvlsui-19', version: '>=19.0', required: false)
# >>>>>>> 6e9963473e8d557f91bc2f89af26c8403a31dfde
if gvls_dep.found() and gvlsp_dep.found() and gvlsui_dep.found()
    subdir('gvls')
endif
