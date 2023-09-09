vim9script

# Note: this is a list because tuples haven't been added yet for whatever dumb
# reason. Same thing in practice, just no size guarantees from lists
def GetTitleContentAndTagArea(line: string): list<number>

    # Find the index of the first tag
    var tagAreaIdx = line->stridx("*")

    # Find the end of the content
    var contentEndIdx = line->match('\v(^| +)\*', 0)

    return [tagAreaIdx, contentEndIdx]
enddef

def SplitTitleLine(line: string): list<string>
    var [tagAreaIdx, contentEndIdx] = GetTitleContentAndTagArea(line)

    var prefix = contentEndIdx <= 0 ? '' : line[: contentEndIdx - 1]
    var tagBlock = line[tagAreaIdx :]
    return [prefix, tagBlock]
enddef

export def AddSectionHeader(symbol: string)
    append(line('.') - 1, [symbol->repeat(&tw)])
enddef

export def AlignSymbolAndTitle(line: number)
    # Warning: this function is at a massive risk of off-by-one errors that
    # cascade down calculations, thanks to a combination of one-indexed and
    # zero-indexed stuff.
    var content = getline(line)
    # Identify the first tag
    var tagStart = content->search()

    var stars = content->count("*")
    if stars < 2
        echom "No tags found"
        # No tags found
        return
    endif
    # This offset represents the number of stars minus one, and is used to
    # align the end of the content perfectly when concealing.
    # The last star will conceal after the text width, and consequently be
    # irrelevant for the calculations.
    # 
    # This is something that might be a config option though. Some people may
    # prefer having the text be within 'textwidth' rather than have the
    # rendered output be within 'textwidth'. Future problem though
    var offset = stars - 1

    var [tagAreaIdx, contentEndIdx] = GetTitleContentAndTagArea(content)
    
    # Find the total length, and compute the length of the tag section
    var tagAreaSize = content->len() - tagAreaIdx

    var space = &tw - contentEndIdx - tagAreaSize + offset + 1
    #echom contentEndIdx tagAreaSize offset
    
    var spaceBlock = space <= 0 ? "" : " "->repeat(space)
    # This should never happen, but may signal a tag block that massively
    # exceeds the &tw width. Abort and let the user sort out their shit
    # manually
    # No warning is provided for good measure, just in case the formatted
    # version 
    if (spaceBlock == "")
        return
    endif
    var [prefix, tagBlock] = SplitTitleLine(content)
    #echom prefix spaceBlock tagBlock
    setline(line('.'), prefix .. spaceBlock .. tagBlock)

enddef

export def AddSection()
    AddSectionHeader("=")
enddef

export def AddSubsection()
    AddSectionHeader("-")
enddef

export def GenerateAndInsertToC()
    var lines = getline(0, line('$'))
    # Where the ToC header starts
    var tocStartLine = -1

    # Where the === divider header for the first section begins, and by
    # definition, the ToC ends.
    var tocEndSectionDivider = -1
    var nextLineIsHeader = false
    var nextLineIsSubsection = false

    # Effectively list<list<tuple<string, string>>>
    # outer list is the titles, inner lists represent a title-tag pair. 
    var toc: list<list<list<string>>> = []
    var secCount = 0

    var longestSectionName = -1

    for i in range(0, len(lines) - 1)
        var line = lines[i]
        if (tocEndSectionDivider == -1)
            # Locate the ToC
            if tocStartLine != -1 && line =~ '\v^\=+$'
                tocEndSectionDivider = i + 1
            elseif tocStartLine == -1 && line =~? '\v^(Table of contents|Contents)\~?'
                # TODO: ToC headers might need far more flexibility than this, but
                # this requires input from more users. A variable might be more
                # appropriate (possibly an array merged for conveniene at buffer 
                # creation? Not sure if that's a good idea or not)
                tocStartLine = i + 1 # Zero-index -> 1-index conversion
                continue
            else
                continue
            endif
        endif

        # Parse the rest of the document for structure
        # Note that this isn't part of the if statement, as there's a single
        # branch of the ToC location system where it has to run. In my
        # documents, the separator for the first section is also the end
        # separator for the ToC. When it's been located, it must be used to
        # signal the end of the ToC area, but it also has to be processed
        # through this system, as it is used for a header.
        #
        # Otherwise, there's an off-by-one error for the first section
        if nextLineIsHeader == false && line =~ '\v^\=+$'
            nextLineIsHeader = true
        elseif nextLineIsHeader == false && nextLineIsSubsection == false && line =~ '\v^-+$'
            nextLineIsSubsection = true
        elseif nextLineIsHeader == true
            var [prefix, tag] = SplitTitleLine(line)
            toc->add([[prefix, tag]])

            longestSectionName = max([prefix->len(), longestSectionName])

            nextLineIsHeader = false
            secCount += 1
        elseif nextLineIsSubsection == true
            var [prefix, tag] = SplitTitleLine(line)
            # We assert there are headers so far. If there aren't,
            # undefined behaviour
            #echom toc
            toc[-1]->add([prefix, tag])

            # + &sw to compensate for subsection indent
            longestSectionName = max([prefix->len() + &sw, longestSectionName])

            nextLineIsSubsection = false
            secCount += 1
        endif
    endfor
    #echom toc

    if tocStartLine == -1 || tocEndSectionDivider == -1
        echoerr "Failed to locate the ToC section area"
        return
    elseif toc->len() == 0
        echoerr "Failed to parse structure"
        return
    endif

    # Safety measure: calculate the ToC area
    var tocAreaEnd = tocEndSectionDivider - 1
    var tocAreaStart = tocStartLine + 1
    # + 10 is an optimistic safety factor. The failure conditions for this is
    # very, very specific.
    # TODO: allow bang commands to override this
    if tocAreaEnd - tocAreaStart > secCount + 10
        echohl WarningMsg
        echom "WARNING: The ToC area identified may exceed the actual bounds of the table of content."
        echom "The length of the table exceeds the allowed safety range. Please verify that only the ToC"
        echom "is within the line range" tocAreaStart "to" tocAreaEnd
        echohl None
        var answer = input("Type y to confirm the insertion (note: use the bang command to default yes, or the double bang command to fail automatically): ")

        if answer != "y"
            echom "Aborting"
            return
        endif
    endif

    var tocOutput = [""]
    # Now, unroll the ToC stack into a list of strings
    for section in toc
        
        for i in range(0, section->len() - 1)
            var [title, rawTag] = section[i]
            if rawTag !~ '\v^\*[^ ]+\*$'
                echoerr "Invalid section declaration at" title "for tag \"" .. rawTag .. "\""
                return
            endif
            var tag = "|" .. rawTag[1 : -2] .. "|"

            var line = " "->repeat(&sw)
            if (i != 0)
                # Double indent for subsections
                line ..= " "->repeat(&sw)
            endif

            line ..= title
            var dotCount = longestSectionName + 24 - line->len()
            line ..= " " .. "."->repeat(dotCount) .. " "
            line ..= tag

            tocOutput->add(line)
        endfor

    endfor
    # Blank line after the list
    tocOutput->add("")

    # First, blank the range
    bufnr()->deletebufline(tocAreaStart, tocAreaEnd)
    append(tocStartLine, tocOutput)
enddef

def InitVariables()

enddef

def InitPlugMaps()
    # T1: Non-contextual or locally contextual mappings that don't put
    # heavy constraints on formatting
    nmap <buffer> <Plug>(T1AddSectionSeparator) :call helpwriter#AddSectionHeader('=')<CR>
    nmap <buffer> <Plug>(T1AddSubsectionSeparator) :call helpwriter#AddSectionHeader('-')<CR>
    nmap <buffer> <Plug>(T1AlignTag) :call helpwriter#AlignSymbolAndTitle(line('.'))<CR>

    # T2: contextual content that assumes certain things about the formatting

    # T3: Heavily contextual content that requires certain things about the
    # formatting to be allowed to function.
    nmap <buffer> <Plug>(T3GenToC) :call helpwriter#GenerateAndInsertToC()<CR>
enddef

def InitCommands()

    command! AddSectionSeparator call <SID>AddSectionHeader('=')
    command! AddSubsectionSeparator call <SID>AddSectionHeader('-')
enddef

def InitMaps()
    nmap <buffer><silent> <leader>ha <Plug>(T1AlignTag)
    # Section abd subsection headers are annoying to deal with. They're not
    # layered, so using \h1 and \h2 doesn't really make sense.
    # [prefix] symbol header
    nmap <buffer><silent> <leader>hsh <Plug>(T1AddSectionSeparator)
    # [prefix] symbol sub[section]
    nmap <buffer><silent> <leader>hss <Plug>(T1AddSubsectionSeparator)

    nmap <buffer><silent> <leader>htg <Plug>(T3GenToC)
enddef

export def SetupBuffer()
    if (&ft != "help")
        return
    endif

    if (&tw == -1)
        setlocal tw = 80
    endif

    InitVariables()
    InitPlugMaps()
    InitCommands()
    InitMaps()

enddef
