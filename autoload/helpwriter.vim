vim9script

def AddSectionHeader(symbol: string)
    append(line('.') - 1, [symbol->repeat(&tw)])
enddef

def AlignSymbolAndTitle(line: number)
    var content = getline(line)
    # Identify the first tag
    var tagStart = content->search()

    var stars = content->count('*')
    if stars < 2
        # No tags found
        return
    endif
    var offset = stars - 1

enddef

def LocateToC()

enddef

export def AddSection()
    AddSectionHeader("=")
enddef

export def AddSubsection()
    AddSectionHeader("-")
enddef

export def SetupBuffer()
    if (&ft != "help")
        return
    endif

    if (&tw == -1)
        set tw = 80
    endif

    command! AddSection call <SID>AddSection()
enddef
