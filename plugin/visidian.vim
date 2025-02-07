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
    let g:visidian_debug = 0
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
let s:has_fzf_plugin = exists('*fzf#run')
let s:has_system_fzf = executable('fzf')
let s:has_bat = executable('bat')

if s:has_fzf_plugin
    if g:visidian_debug
        echom "Visidian: Using FZF Vim plugin for search"
        echom "Visidian: Using " . (s:has_bat ? "bat" : "cat") . " for preview"
    endif
elseif s:has_system_fzf
    if g:visidian_debug
        echom "Visidian: Using system FZF for search"
        echom "Visidian: Using " . (s:has_bat ? "bat" : "cat") . " for preview"
    endif
else
    if g:visidian_debug
        echom "Visidian: Using Vim's built-in search (no FZF available)"
    endif
endif

" Set up session options
set sessionoptions=blank,buffers,curdir,folds,help,tabpages,winsize,terminal

" Load autoload functions
runtime! autoload/visidian.vim

" Exposes the plugins functions for use with following commands: 
command! -nargs=0 VisidianDash call visidian#dashboard()
command! -nargs=0 VisidianFile call visidian#new_md_file()
command! -nargs=0 VisidianFolder call visidian#new_folder()
command! -nargs=0 VisidianVault call visidian#create_vault()
command! -nargs=0 VisidianLink call visidian#link_notes()
command! -nargs=0 VisidianParaGen call visidian#create_para_folders()
command! -nargs=0 VisidianHelp call visidian#help()
command! -nargs=0 VisidianSync call visidian#sync()
command! -nargs=0 VisidianToggleAutoSync call visidian#toggle_auto_sync()
command! -nargs=0 VisidianTogglePreview call visidian#toggle_preview()
command! -nargs=0 VisidianToggleSidebar call visidian#toggle_sidebar()
command! -nargs=0 VisidianSearch call visidian#search()
command! -nargs=0 VisidianSort call visidian#sort()
command! -nargs=0 VisidianMenu call visidian#menu()

" Add toggle search command
command! -nargs=0 VisidianToggleSearch call visidian#search#toggle()

" Session management commands
command! -nargs=0 VisidianSaveSession call visidian#save_session()
command! -nargs=0 VisidianLoadSession call visidian#load_session()
command! -nargs=0 VisidianListSessions call visidian#list_sessions()
command! -nargs=0 VisidianChooseSession call visidian#choose_session()
command! -nargs=0 VisidianClearSessions call visidian#clear_sessions()

" Generate & Browse Ctags
command! -nargs=0 VisidianGenCtags call VisidianGenerateTags()
command! -nargs=0 VisidianBrowseCtags call VisidianBrowseTags()

"Toggle Spelling
command! -nargs=0 VisidianToggleSpell call visidian#toggle_spell()

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
        
        if l:path =~? '/Projects/'
            let l:hi_group = '%#VisidianProjects#'
        elseif l:path =~? '/Areas/'
            let l:hi_group = '%#VisidianAreas#'
        elseif l:path =~? '/Resources/'
            let l:hi_group = '%#VisidianResources#'
        elseif l:path =~? '/Archives/'
            let l:hi_group = '%#VisidianArchives#'
        endif

        " Preserve existing statusline or set a basic one
        if empty(&statusline)
            setlocal statusline=%<%f\ %h%m%r%=%-14.(%l,%c%V%)\ %P
        endif
        
        " Add PARA context with color if not already present
        if !empty(l:hi_group)
            let l:para_status = l:hi_group . visidian#para_status() . '%*'
            if &statusline !~# escape(l:para_status, '[]')
                execute 'setlocal statusline^=' . escape(l:para_status, ' ')
            endif
        endif
    endif
endfunction
