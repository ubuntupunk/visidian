"file: autload/visidian/search.vim
"this is the search function called by the VisidianSearch command

"FUNCTION: Search
function! visidian#search#search()
    if g:visidian_vault_path == ''
        echoerr "No vault path set. Please create or set a vault first."
        return
    endif

    let query = input("Enter search query: ")
    if empty(query)
        echo "No query provided."
        return
    endif

    if executable('fzf')
        call s:fzf_search(query)
    else
        call s:vim_search(query)
    endif
endfunction

"FUNCTION: FZF search query
function! s:fzf_search(query)
    let files = split(globpath(g:visidian_vault_path, '**/*.md'), '\n')
    let command = printf("fzf --preview='cat {}' --query='%s'", a:query)
    let selected = systemlist(command, files)
    if !empty(selected)
        for file in selected
            execute 'edit ' . file
        endfor
    else
        echo "No matches found."
    endif
endfunction

"FUNCTION vimgrep search
function! s:vim_search(query)
    " Use vimgrep for fallback search
    let pattern = escape(a:query, '/\*')
    try
        " Search all .md files in the vault
        execute 'vimgrep /' . pattern . '/j ' . fnameescape(g:visidian_vault_path . '**/*.md')
        " Open quickfix window
        copen
    catch /^Vim\%((\a\+)\)\=:E480/
        echo "No matches found."
    endtry
endfunction
