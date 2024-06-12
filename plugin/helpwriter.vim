vim9script

import autoload "helpwriter.vim" as hw

augroup HelpWriter
    au!
    au FileType help call <SID>hw.SetupBuffer()
augroup END
