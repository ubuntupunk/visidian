"file: autoload/visidian/search.vim
"this is the search function called by the VisidianSearch command

" Track search state
let s:search_active = 0

"FUNCTION: Toggle search
function! visidian#search#toggle()
    if s:search_active
        call visidian#debug#debug('SEARCH', 'Closing search...')
        call s:close_search()
    else
        call visidian#debug#debug('SEARCH', 'Opening search...')
        call visidian#search#search()
    endif
endfunction

"FUNCTION: Close search
function! s:close_search()
    if exists('*fzf#run')
        " For FZF plugin
        try
            call fzf#exit()
            call visidian#debug#debug('SEARCH', 'Closed FZF window')
        catch
            call visidian#debug#debug('SEARCH', 'FZF window already closed')
        endtry
    else
        " For system FZF and vim search
        silent! execute "normal! \<C-c>"
        silent! cclose
        call visidian#debug#debug('SEARCH', 'Closed search window')
    endif
    let s:search_active = 0
endfunction

"FUNCTION: Search
function! visidian#search#search()
    call visidian#debug#debug('SEARCH', 'Starting search function...')
    
    if g:visidian_vault_path == ''
        call visidian#debug#error('SEARCH', 'No vault path set')
        echohl ErrorMsg
        echo "No vault path set. Please create or set a vault first."
        echohl None
        return
    endif

    let query = input("Enter search query: ")
    if empty(query)
        call visidian#debug#info('SEARCH', 'Empty search query')
        echo "No query provided."
        return
    endif

    call visidian#debug#debug('SEARCH', 'Search query: ' . query)
    let s:search_active = 1

    " Try search methods in order: vim built-in, fzf, fzf.vim
    if exists('*fzf#run')
        call visidian#debug#info('SEARCH', 'Using FZF')
        call s:fzf_search(query)
    else
        call visidian#debug#info('SEARCH', 'Using Vim built-in search')
        call s:vim_search(query)
    endif
endfunction

"FUNCTION: FZF search
function! s:fzf_search(query)
    call visidian#debug#debug('SEARCH', 'Starting FZF search...')
    
    " Save current window and buffer
    let s:last_win = winnr()
    let s:last_buf = bufnr('%')
    
    " Build the command to find markdown files
    let find_cmd = 'find ' . shellescape(g:visidian_vault_path) . ' -type f -name "*.md"'
    
    " Create options dictionary for fzf
    let opts = {}
    let opts.source = find_cmd
    let opts.sink = function('s:open_file')
    let opts.options = ['--prompt', 'Search> ',
                     \ '--preview', 'grep -h -C 3 ' . shellescape(a:query) . ' {}']
    
    try
        call fzf#run(extend(opts, get(g:, 'fzf_layout', {'down': '40%'})))
        call visidian#debug#debug('SEARCH', 'FZF search started successfully')
    catch
        call visidian#debug#error('SEARCH', 'FZF search failed: ' . v:exception)
        " Return to original window if FZF fails
        if exists('s:last_win')
            execute s:last_win . 'wincmd w'
        endif
        call s:vim_search(a:query)  " Fallback to vim search
    endtry
endfunction

"FUNCTION: Open file handler for FZF
function! s:open_file(file)
    " If we have a previous window, try to use it
    if exists('s:last_win') && winbufnr(s:last_win) != -1
        execute s:last_win . 'wincmd w'
    endif
    execute 'edit ' . fnameescape(a:file)
endfunction

"FUNCTION: Vim search
function! s:vim_search(query)
    call visidian#debug#debug('SEARCH', 'Starting Vim built-in search...')
    try
        " Use Vim's built-in vimgrep
        execute 'noautocmd vimgrep /' . escape(a:query, '/\') . '/j ' . g:visidian_vault_path . '/**/*.md'
        copen
        call visidian#debug#debug('SEARCH', 'Vim search completed successfully')
    catch
        call visidian#debug#error('SEARCH', 'Vim search failed: ' . v:exception)
        echohl ErrorMsg
        echo "Search failed: " . v:exception
        echohl None
        let s:search_active = 0
    endtry
endfunction
