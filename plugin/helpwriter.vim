vim9script

if exists("g:HelpWriterLoaded")
    finish
endif
g:HelpWriterLoaded = 1

import autoload "helpwriter.vim" as hw

augroup HelpWriter
    au!
    au FileType help call <SID>hw.SetupBuffer()
augroup END
