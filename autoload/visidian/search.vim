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
    if executable('fzf') && exists('*fzf#vim#with_preview')
        call visidian#debug#info('SEARCH', 'Using FZF.vim with preview')
        call s:fzf_vim_search(query)
    elseif executable('fzf')
        call visidian#debug#info('SEARCH', 'Using system FZF')
        call s:system_fzf_search(query)
    else
        call visidian#debug#info('SEARCH', 'Using Vim built-in search')
        call s:vim_search(query)
    endif
endfunction

"FUNCTION: FZF.vim search with preview
function! s:fzf_vim_search(query)
    call visidian#debug#debug('SEARCH', 'Starting FZF.vim search with preview...')
    try
        call fzf#vim#grep('grep -r ' . shellescape(a:query) . ' ' . g:visidian_vault_path, 1, fzf#vim#with_preview(), 0)
        call visidian#debug#debug('SEARCH', 'FZF.vim search started successfully')
    catch
        call visidian#debug#error('SEARCH', 'FZF.vim search failed: ' . v:exception)
        call s:system_fzf_search(a:query)  " Fallback to system FZF
    endtry
endfunction

"FUNCTION: System FZF search
function! s:system_fzf_search(query)
    call visidian#debug#debug('SEARCH', 'Starting system FZF search...')
    
    let search_cmd = 'grep -r ' . shellescape(a:query) . ' ' . shellescape(g:visidian_vault_path)
    let preview_cmd = 'cat {}'
    
    " Build the fzf command
    let fzf_cmd = 'fzf --ansi --delimiter : --preview "' . preview_cmd . '" --preview-window "+{2}-/2"'
    let full_cmd = search_cmd . ' | ' . fzf_cmd
    
    call visidian#debug#debug('SEARCH', 'Running command: ' . full_cmd)
    
    " Run fzf in a terminal buffer
    let buf = term_start(['/bin/sh', '-c', full_cmd], {
        \ 'term_name': 'visidian-search',
        \ 'hidden': 1,
        \ 'term_finish': 'close',
        \ 'curwin': 1,
        \ })
    
    if buf == 0
        call visidian#debug#error('SEARCH', 'Failed to start terminal for fzf')
        call s:vim_search(a:query)  " Fallback to vim search
    else
        call visidian#debug#debug('SEARCH', 'System FZF search started successfully')
    endif
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
