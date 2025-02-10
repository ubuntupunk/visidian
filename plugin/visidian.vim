" Title: Visidian.vim
" Description: A plugin for vim that imitates obsidian 
" Last Change: 2024-01-11
" Maintainer: David Robert Lewis 
" Email: ubuntupunk at gmail dot com 
" License: GPL-3.0 
" License Details: https://www.gnu.org/licenses/gpl-3.0.en.html

" Prevents the plugin from being loaded multiple times
if exists("g:loaded_visidian_vim")
    finish
endif

let g:loaded_visidian_vim = 1

" Initialize plugin variables
if !exists('g:visidian_debug')
    let g:visidian_debug = 1
endif
if !exists('g:visidian_debug_level')
    let g:visidian_debug_level = 'WARN'
endif
if !exists('g:visidian_debug_categories')
    let g:visidian_debug_categories = ['ALL']
endif
if !exists('g:visidian_vault_path')
    let g:visidian_vault_path = ''
endif

" Add debug commands
command! -nargs=1 -complete=customlist,s:debug_level_complete VisidianDebug call visidian#debug#set_level(<q-args>)
command! -nargs=+ -complete=customlist,s:debug_category_complete VisidianDebugCat call visidian#debug#set_categories([<f-args>])

" Command completion functions
function! s:debug_level_complete(ArgLead, CmdLine, CursorPos)
    return filter(['ERROR', 'WARN', 'INFO', 'DEBUG', 'TRACE'], 'v:val =~? "^" . a:ArgLead')
endfunction

function! s:debug_category_complete(ArgLead, CmdLine, CursorPos)
    return filter(['ALL', 'CORE', 'SESSION', 'PREVIEW', 'SEARCH', 'CACHE', 'PARA', 'UI', 'SYNC', 'BOOKMARKS', 'LINK', 'NOTES'], 'v:val =~? "^" . a:ArgLead')
endfunction

" Initialize essential commands
if !exists(':VisidianSession')
    command! -nargs=0 VisidianSession call visidian#menu_session()
endif

if !exists(':VisidianBook')
    command! -nargs=0 VisidianBook call visidian#bookmarking#menu()
endif

" Initialize PARA color system
if !exists('g:visidian_para_colors')
    let g:visidian_para_colors = {
        \ 'projects': {'ctermfg': '168', 'guifg': '#d75f87'},
        \ 'areas': {'ctermfg': '107', 'guifg': '#87af5f'},
        \ 'resources': {'ctermfg': '110', 'guifg': '#87afd7'},
        \ 'archives': {'ctermfg': '242', 'guifg': '#6c6c6c'}
        \ }
endif

" Define highlight groups for statusline
hi clear VisidianProjects
hi clear VisidianAreas
hi clear VisidianResources
hi clear VisidianArchives

hi def VisidianProjects   term=bold cterm=bold ctermfg=168 gui=bold guifg=#d75f87
hi def VisidianAreas      term=bold cterm=bold ctermfg=107 gui=bold guifg=#87af5f
hi def VisidianResources  term=bold cterm=bold ctermfg=110 gui=bold guifg=#87afd7
hi def VisidianArchives   term=bold cterm=bold ctermfg=242 gui=bold guifg=#6c6c6c

" Check search method availability
let s:has_fzf = exists('*fzf#run')

if g:visidian_debug_level == 'DEBUG'
    call visidian#debug#debug('CORE', 'Search capabilities:')
    call visidian#debug#debug('CORE', '  FZF: ' . (s:has_fzf ? 'yes' : 'no'))
    call visidian#debug#debug('CORE', '  Vim built-in: yes')
endif

if s:has_fzf
    call visidian#debug#info('CORE', 'Using FZF for search')
else
    call visidian#debug#info('CORE', 'Using Vim built-in search')
endif

" Set up session options
set sessionoptions=blank,buffers,curdir,folds,help,tabpages,winsize,terminal

" Load autoload functions
runtime! autoload/visidian.vim

" Exposes the plugins functions for use with following commands: 
command! -nargs=0 VisidianDash call visidian#dashboard()
command! -nargs=0 VisidianNote call visidian#new_md_file()
command! -nargs=0 VisidianFolder call visidian#new_folder()
command! -nargs=0 VisidianVault call visidian#create_vault()
command! -nargs=0 VisidianLink call visidian#link_notes#link_notes()
command! -nargs=0 VisidianClick call visidian#link_notes#click_yaml_link()
command! -nargs=0 VisidianParaGen call visidian#create_para_folders()
command! -nargs=0 VisidianHelp call visidian#help()
command! -nargs=0 VisidianSync call visidian#sync()
command! -nargs=0 VisidianToggleAutoSync call visidian#toggle_auto_sync()
command! -nargs=0 VisidianTogglePreview call visidian#toggle_preview()
command! -nargs=0 VisidianToggleSidebar call visidian#toggle_sidebar()
command! -nargs=0 VisidianSearch call visidian#search()
command! -nargs=0 VisidianSort call visidian#sort()
command! -nargs=0 VisidianMenu call visidian#menu()
command! -nargs=0 VisidianImport call visidian#import()
command! -nargs=0 VisidianBook call visidian#bookmarking#menu()
command! -nargs=0 VisidianToggleSearch call visidian#search#toggle()

" Generate & Browse Ctags
command! -nargs=0 VisidianGenCtags call VisidianGenerateTags()
command! -nargs=0 VisidianBrowseCtags call VisidianBrowseTags()

"Toggle Spelling
command! -nargs=0 VisidianToggleSpell call visidian#toggle_spell()

" Optional: Map YAML link clicking to <CR> in YAML frontmatter
augroup VisidianYAMLLinks
    autocmd!
    autocmd FileType markdown nnoremap <buffer> <CR> :call visidian#link_notes#click_yaml_link()<CR>
augroup END

" Set up autocommands for statusline
augroup VisidianStatusLine
    autocmd!
    " Update statusline for markdown files in vault
    autocmd BufEnter,BufWritePost *.md call s:UpdateVisidianStatusLine()
augroup END

function! s:UpdateVisidianStatusLine()
    " Only modify statusline for markdown files in vault
    if &filetype == 'markdown' || &filetype == 'visidian'
        " Get PARA context
        let l:path = expand('%:p')
        let l:hi_group = ''
        let l:filetype_indicator = ''

        " Set filetype indicator
        if &filetype == 'visidian'
            let l:filetype_indicator = '[Visidian]'

        " Debug path matching
        if g:visidian_debug_level == 'DEBUG'
            call visidian#debug#trace('UI', 'Statusline Path: ' . l:path)
        endif

        " Set PARA context color    
        if l:path =~? '/Projects/'
            let l:hi_group = '%#VisidianProjects#'
        elseif l:path =~? '/Areas/'
            let l:hi_group = '%#VisidianAreas#'
        elseif l:path =~? '/Resources/'
            let l:hi_group = '%#VisidianResources#'
        elseif l:path =~? '/Archive\|Archives/'
            let l:hi_group = '%#VisidianArchives#'
        endif
    else
        let l:filetype_indicator = '[Markdown]'
        endif
        
        " Preserve existing statusline or set a basic one
        "if empty(&statusline)
            "setlocal statusline=%<%f\ %h%m%r%=%-14.(%l,%c%V%)\ %P
        "endif
        
        " Set statusline with filetype and timestamp
        "let &l:statusline = '%<%f\ %h%m%r\ ' . l:filetype_indicator . '\ %{strftime(''%c'',getftime(expand(''%'')))}%=%-14.(%l,%c%V%)\ %P'
     
        " Process the display path first
        let l:display_path = expand('%:p') 
        if !empty(l:hi_group)
            " Remove the PARA directory from the display path
            if l:display_path =~? '/Projects/'
                let l:display_path = substitute(l:display_path, '.*/Projects/', '', '')
            elseif l:display_path =~? '/Areas/'
                let l:display_path = substitute(l:display_path, '.*/Areas/', '', '')
            elseif l:display_path =~? '/Resources/'
                let l:display_path = substitute(l:display_path, '.*/Resources/', '', '')
            elseif l:display_path =~? '/Archive\|Archives/'
                let l:display_path = substitute(l:display_path, '.*/Arch\(ive\|ives\)/', '', '')
            endif
        endif
             
        " " Format: [P/A/R/A] filename Type: Visidian/Markdown │ HH:MM
        " let &l:statusline = ''
        " if !empty(l:hi_group)
        "     let l:para_status = l:hi_group . visidian#para_status() . '%* '
        "     let &l:statusline .= l:para_status
        " endif
        " let &l:statusline .= '%<%f %h%m%r'
        " let &l:statusline .= '%='
        " let &l:statusline .= l:filetype_indicator . ' │ %{strftime("%H:%M")} '
        
        " Build statusline components
        let l:left_section = ''
            if !empty(l:hi_group)
                let l:left_section .= l:hi_group . visidian#para_status() . '%* '
            endif
            let l:left_section .= '%<' . l:display_path . ' %h%m%r'

        let l:right_section = l:filetype_indicator . ' │ %{strftime("%H:%M")} '

        " Set the complete statusline
        let &l:statusline = l:left_section
        let &l:statusline .= '%='  " Right align divider
        let &l:statusline .= l:right_section

        " Add PARA context with color if not already present
        " if !empty(l:hi_group)
        "     let l:para_status = l:hi_group . visidian#para_status() . '%*'
        "     if &statusline !~# escape(l:para_status, '[]')
        "         execute 'setlocal statusline^=' . escape(l:para_status, ' ')
        "     endif
        " endif
    endif
endfunction
