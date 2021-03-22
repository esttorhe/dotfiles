syn region dosiniSection start="^\[" end="\(\n\+\[\)\@=" contains=dosiniLabel,dosiniHeader,dosiniComment keepend fold
setlocal foldmethod=syntax
" Following opens all folds (remove line to start with folds closed).
setlocal foldlevel=20

syn match  dosinicomment        "^;.*$\|^#.*$"
syn match  dosinilabel          "^\s\+ ="

" Handle heredoc syntax in the dosini syntax.
" Taken from syntax/perl.ini (:%s/perl/dosini/g).
if exists("dosini_string_as_statement")
  HiLink dosiniStringStartEnd   dosiniStatement
endif

syn region dosiniHereDoc matchgroup=dosiniStringStartEnd start=+<<\z(\I\i*\)+      end=+^\z1$+ contains=@dosiniInterpDQ
syn region dosiniHereDoc matchgroup=dosiniStringStartEnd start=+<<\s*"\z(.\{-}\)"+ end=+^\z1$+ contains=@dosiniInterpDQ
syn region dosiniHereDoc matchgroup=dosiniStringStartEnd start=+<<\s*'\z(.\{-}\)'+ end=+^\z1$+ contains=@dosiniInterpSQ
syn region dosiniHereDoc matchgroup=dosiniStringStartEnd start=+<<\s*""+           end=+^$+    contains=@dosiniInterpDQ,dosiniNotEmptyLine
syn region dosiniHereDoc matchgroup=dosiniStringStartEnd start=+<<\s*''+           end=+^$+    contains=@dosiniInterpSQ,dosiniNotEmptyLine
