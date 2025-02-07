"file: autoload/visidian/search.vim
"this is the search function called by the VisidianSearch command

"FUNCTION: Search
function! visidian#search#search()
    if g:visidian_vault_path == ''
        echoerr "No vault path set. Please create or set a vault first."
        return
    endif

    " Debug mode can be enabled by setting g:visidian_debug = 1
    let s:debug = get(g:, 'visidian_debug', 0)

    if s:debug | echom "Starting search..." | endif

    let query = input("Enter search query: ")
    if empty(query)
        echo "No query provided."
        return
    endif

    if s:debug | echom "Query received: " . query | endif

    " Check for FZF availability (either plugin or system)
    if exists('*fzf#run')
        if s:debug | echom "Using Vim FZF plugin" | endif
        call s:fzf_plugin_search(query)
    elseif executable('fzf')
        if s:debug | echom "Using system FZF" | endif
        call s:fzf_system_search(query)
    else
        if s:debug | echom "Using Vim's built-in search" | endif
        call s:vim_search(query)
    endif
endfunction

"FUNCTION: Get preview command
function! s:get_preview_cmd()
    return executable('bat') ? 'bat --color=always {}' : 'cat {}'
endfunction

"FUNCTION: FZF plugin search
function! s:fzf_plugin_search(query)
    let files = split(globpath(g:visidian_vault_path, '**/*.md'), '\n')
    if empty(files)
        echo "No markdown files found in vault."
        return
    endif

    if s:debug | echom "Found " . len(files) . " markdown files" | endif
    
    let preview_cmd = s:get_preview_cmd()
    let opts = {
        \ 'source': files,
        \ 'sink': 'edit',
        \ 'options': ['--preview', preview_cmd,
        \            '--query', a:query,
        \            '--prompt', 'Search Notes> '],
        \ 'down': '40%'
        \ }

    if s:debug | echom "Launching FZF plugin with options: " . string(opts) | endif

    try
        call fzf#run(fzf#wrap(opts))
    catch
        echoerr "Vim FZF plugin search failed: " . v:exception
        if s:debug
            echom "Error details: " . v:throwpoint
        endif
    endtry
endfunction

"FUNCTION: FZF system search
function! s:fzf_system_search(query)
    let files = split(globpath(g:visidian_vault_path, '**/*.md'), '\n')
    if empty(files)
        echo "No markdown files found in vault."
        return
    endif

    if s:debug | echom "Found " . len(files) . " markdown files" | endif

    " Escape special characters in query
    let escaped_query = shellescape(a:query)
    let preview_cmd = shellescape(s:get_preview_cmd())
    let command = printf("fzf --preview=%s --query=%s", preview_cmd, escaped_query)

    if s:debug | echom "FZF system command: " . command | endif

    try
        let selected = systemlist(command, files)
        if v:shell_error
            throw "FZF error: " . string(selected)
        endif
        
        if !empty(selected)
            for file in selected
                if filereadable(file)
                    execute 'edit ' . fnameescape(file)
                else
                    echoerr "Cannot read file: " . file
                endif
            endfor
        else
            echo "No matches found."
        endif
    catch
        echoerr "System FZF search failed: " . v:exception
        if s:debug
            echom "Error details: " . v:throwpoint
        endif
    endtry
endfunction

"FUNCTION: Vim's built-in search
function! s:vim_search(query)
    if s:debug | echom "Starting Vim built-in search..." | endif

    " Escape special characters in the pattern
    let pattern = escape(a:query, '/\*')
    if s:debug | echom "Search pattern: " . pattern | endif

    try
        " First check if there are any markdown files
        let files = glob(g:visidian_vault_path . '**/*.md', 0, 1)
        if empty(files)
            echo "No markdown files found in vault."
            return
        endif

        if s:debug | echom "Found " . len(files) . " markdown files to search" | endif

        " Search all .md files in the vault
        execute 'noautocmd vimgrep /' . pattern . '/j ' . fnameescape(g:visidian_vault_path . '**/*.md')
        
        " Get the number of matches
        let num_matches = len(getqflist())
        if s:debug | echom "Found " . num_matches . " matches" | endif

        if num_matches > 0
            " Open quickfix window
            copen
            echo "Found " . num_matches . " matches."
        else
            echo "No matches found."
        endif
    catch /^Vim\%((\a\+)\)\=:E480/
        echo "No matches found."
    catch
        echoerr "Vim search failed: " . v:exception
        if s:debug
            echom "Error details: " . v:throwpoint
        endif
    endtry
endfunction
