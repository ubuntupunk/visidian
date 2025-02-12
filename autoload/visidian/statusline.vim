" Statusline functions for Visidian
" Author: Visidian Team
" License: MIT

" Function: visidian#statusline#is_image
" Description: Check if current buffer is an image file
function! visidian#statusline#is_image()
    let l:ext = tolower(expand('%:e'))
    return index(['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'], l:ext) >= 0
endfunction

" Function: visidian#statusline#image_indicator
" Description: Get image indicator if current buffer is an image
function! visidian#statusline#image_indicator()
    if visidian#statusline#is_image()
        " Add [I] on left, [Visidian] on right if there's space
        return '%#VisidianImageConcern#[I]%* %<%f %{&modified?"[+]":""} %= %{winwidth(0)>70?"[Visidian] ":""}'
    endif
    return ''
endfunction

" Initialize highlight groups
function! visidian#statusline#init_highlights()
    " Define image concern highlight with unique purple color
    highlight VisidianImageConcern guifg=#ffffff guibg=#9B6BDF ctermfg=255 ctermbg=98
endfunction
