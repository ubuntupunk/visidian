" Detect Visidian dashboard buffer
au BufRead,BufNewFile Visidian-Dashboard set filetype=visidian

" Detect markdown files in Visidian vault
augroup VisidianMarkdown
    autocmd!
    autocmd BufRead,BufNewFile *.md call s:CheckVisidianMarkdown()
augroup END

function! s:CheckVisidianMarkdown()
    " Only set filetype if we're in the Visidian vault
    if exists('g:visidian_vault_path') && !empty(g:visidian_vault_path)
        let current_path = expand('%:p')
        let vault_path = g:visidian_vault_path
        
        " Normalize paths for comparison
        let current_path = substitute(current_path, '\\', '/', 'g')
        let vault_path = substitute(vault_path, '\\', '/', 'g')
        
        " Remove trailing slash from vault path if present
        let vault_path = substitute(vault_path, '/$', '', '')
        
        " Check if current file is in vault
        if current_path =~# '^' . escape(vault_path, '/') . '/'
            set filetype=visidian
        endif
    endif
endfunction
