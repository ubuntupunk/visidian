" Statusline functions for Visidian
" Author: Visidian Team
" License: MIT

" Function: visidian#statusline#is_image
" Description: Check if current buffer is an image file
function! visidian#statusline#is_image()
    let l:ext = tolower(expand('%:e'))
    return index(['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'], l:ext) >= 0
endfunction

" Function: visidian#statusline#get_para_location
" Description: Get PARA location of current file
function! visidian#statusline#get_para_location()
    let l:path = expand('%:p')
    if l:path =~? '/Projects/'
        return 'Project'
    elseif l:path =~? '/Areas/'
        return 'Area'
    elseif l:path =~? '/Resources/'
        return 'Resource'
    elseif l:path =~? '/Archives/'
        return 'Archive'
    endif
    return ''
endfunction

" Function: visidian#statusline#image_indicator
" Description: Get image indicator if current buffer is an image
function! visidian#statusline#image_indicator()
    if visidian#statusline#is_image()
        let l:para = visidian#statusline#get_para_location()
        let l:para_text = empty(l:para) ? '' : ' ' . l:para . ' '
        return '%#VisidianImageConcern#[I]%*' . l:para_text . '%{winwidth(0)>70?"[Visidian] ":""}'
    endif
    return ''
endfunction

" Initialize highlight groups
function! visidian#statusline#init_highlights()
    " Define image concern highlight with unique purple color
    highlight VisidianImageConcern guifg=#ffffff guibg=#9B6BDF ctermfg=255 ctermbg=98
endfunction
