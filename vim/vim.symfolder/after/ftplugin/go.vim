set shiftwidth=4 " size of an "indent"
set tabstop=4 " size of a hard tabstop
set softtabstop=4 " size of a soft tabstop
set expandtab " always uses spaces instead of tab characters
set autoindent " automatically indent go files
set smartindent
setlocal path=.,**
setlocal wildignore=.bak,.o,.info,.swp,.obj  

let g:go_fmt_autosave = 1
let g:go_fmt_command = "gofmt"
let g:go_asmfmt_autosave = 0
let g:go_fmt_options = {
\ 'gofmt': '-s',
\ 'goimports': '-local soundcloud.com winkoz.com',
\ }
