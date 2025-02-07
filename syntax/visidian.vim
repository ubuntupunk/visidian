" Quit if syntax file is already loaded
if exists("b:current_syntax")
    finish
endif

" Include markdown syntax as base
runtime! syntax/markdown.vim

" Define dashboard-specific syntax patterns
syntax match VisidianAsciiArt /^[ ]\+_\s*.\+$\|^[ ]\+|.\+|\s*$\|^[ ]\+\\.\+\\/\s*$\|^[ ]\+\\.*_.*/_\s*$/
syntax match VisidianVaultPath /^[ ]\+Current Vault:.*$/
syntax match VisidianCommandTitle /^[ ]\+Available Commands:.*$/
syntax match VisidianCommand /^[ ]\+:Visidian\w\+/
syntax match VisidianTipTitle /^[ ]\+Tip:.*$/
syntax match VisidianProTip /^[ ]\+Pro Tip:.*$/

" Set highlight colors
highlight VisidianAsciiArt ctermfg=39 guifg=#00afff
highlight VisidianVaultPath ctermfg=142 guifg=#afaf00
highlight VisidianCommandTitle ctermfg=214 guifg=#ffaf00
highlight VisidianCommand ctermfg=77 guifg=#5fd75f
highlight VisidianTipTitle ctermfg=168 guifg=#d75f87
highlight VisidianProTip ctermfg=205 guifg=#ff5faf

" Additional Visidian-specific markdown enhancements
" Enhance link highlighting
syntax match VisidianWikiLink /\[\[[^\]]\+\]\]/
highlight VisidianWikiLink ctermfg=111 guifg=#87afff

" Enhance TODO highlighting
syntax match VisidianTodo /\[ \].*$/ contains=VisidianCheckbox
syntax match VisidianDone /\[x\].*$/ contains=VisidianCheckbox
syntax match VisidianCheckbox /\[ \]/ contained
syntax match VisidianCheckbox /\[x\]/ contained

highlight VisidianTodo ctermfg=yellow guifg=#ffff00
highlight VisidianDone ctermfg=green guifg=#00ff00
highlight VisidianCheckbox ctermfg=blue guifg=#0000ff

" PARA Method Color System
" Default colors can be customized via g:visidian_para_colors
if !exists('g:visidian_para_colors')
    let g:visidian_para_colors = {
        \ 'projects': {'ctermfg': '168', 'guifg': '#d75f87'},  " Pink - Active, time-bound
        \ 'areas': {'ctermfg': '107', 'guifg': '#87af5f'},     " Green - Ongoing responsibility
        \ 'resources': {'ctermfg': '110', 'guifg': '#87afd7'}, " Blue - Reference material
        \ 'archives': {'ctermfg': '242', 'guifg': '#6c6c6c'},  " Gray - Inactive
        \ }
endif

" PARA folder patterns
syntax match VisidianProjectFolder /^Projects\/.*$/ contains=VisidianWikiLink
syntax match VisidianAreaFolder /^Areas\/.*$/ contains=VisidianWikiLink
syntax match VisidianResourceFolder /^Resources\/.*$/ contains=VisidianWikiLink
syntax match VisidianArchiveFolder /^Archives\/.*$/ contains=VisidianWikiLink

" Apply colors from configuration
execute 'highlight VisidianProjectFolder ctermfg=' . g:visidian_para_colors.projects.ctermfg . ' guifg=' . g:visidian_para_colors.projects.guifg
execute 'highlight VisidianAreaFolder ctermfg=' . g:visidian_para_colors.areas.ctermfg . ' guifg=' . g:visidian_para_colors.areas.guifg
execute 'highlight VisidianResourceFolder ctermfg=' . g:visidian_para_colors.resources.ctermfg . ' guifg=' . g:visidian_para_colors.resources.guifg
execute 'highlight VisidianArchiveFolder ctermfg=' . g:visidian_para_colors.archives.ctermfg . ' guifg=' . g:visidian_para_colors.archives.guifg

" PARA Status Line Support
function! VisidianParaContext()
    let l:path = expand('%:p')
    let l:para_type = ''
    
    if l:path =~? '/Projects/'
        let l:para_type = 'P'
    elseif l:path =~? '/Areas/'
        let l:para_type = 'A'
    elseif l:path =~? '/Resources/'
        let l:para_type = 'R'
    elseif l:path =~? '/Archives/'
        let l:para_type = 'Ar'
    endif
    
    return l:para_type
endfunction

" Set current syntax
let b:current_syntax = "visidian"
