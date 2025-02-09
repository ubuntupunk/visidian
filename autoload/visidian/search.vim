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

    " Check for required executables
    if !executable('rg')
        call visidian#debug#error('SEARCH', 'ripgrep (rg) not found')
        echohl ErrorMsg
        echo "ripgrep (rg) is required for search functionality but was not found in PATH"
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

    " Check search method availability
    if exists('*fzf#run')
        call visidian#debug#info('SEARCH', 'Using FZF plugin')
        call s:fzf_search(query)
    elseif executable('fzf')
        call visidian#debug#info('SEARCH', 'Using system FZF')
        call s:system_fzf_search(query)
    else
        call visidian#debug#info('SEARCH', 'Using Vim built-in search')
        call s:vim_search(query)
    endif
endfunction

"FUNCTION: FZF plugin search
function! s:fzf_search(query)
    call visidian#debug#debug('SEARCH', 'Starting FZF plugin search...')
    
    let command = 'rg --column --line-number --no-heading --color=always --smart-case '
    let initial_command = command . shellescape(a:query)
    
    try
        " Check if fzf.vim's preview function is available
        if exists('*fzf#vim#with_preview')
            call visidian#debug#debug('SEARCH', 'Using fzf.vim with preview')
            call fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(), 0)
        else
            " Fall back to basic fzf if fzf.vim is not available
            call visidian#debug#warn('SEARCH', 'fzf.vim not found, falling back to system fzf')
            call s:system_fzf_search(a:query)
        endif
        call visidian#debug#debug('SEARCH', 'FZF search started successfully')
    catch
        call visidian#debug#error('SEARCH', 'FZF search failed: ' . v:exception)
        echohl ErrorMsg
        echo "FZF search failed: " . v:exception . ". Please ensure fzf.vim is installed for full functionality."
        echohl None
        let s:search_active = 0
    endtry
endfunction

"FUNCTION: System FZF search
function! s:system_fzf_search(query)
    call visidian#debug#debug('SEARCH', 'Starting system FZF search...')
    
    let search_cmd = 'rg --column --line-number --no-heading --color=always --smart-case ' . shellescape(a:query) . ' ' . shellescape(g:visidian_vault_path)
    let preview_cmd = 'bat --style=numbers --color=always {} || cat {}'
    
    " Build the fzf command
    let fzf_cmd = 'fzf --ansi --delimiter : --preview "' . preview_cmd . '" --preview-window "+{2}-/2"'
    let full_cmd = search_cmd . ' | ' . fzf_cmd
    
    call visidian#debug#debug('SEARCH', 'Running command: ' . full_cmd)
    
    " Save the current buffer number
    let current_buf = bufnr('%')
    
    " Run fzf in a terminal buffer
    let buf = term_start(['/bin/sh', '-c', full_cmd], {
        \ 'term_name': 'visidian-search',
        \ 'hidden': 1,
        \ 'term_finish': 'close',
        \ 'curwin': 1,
        \ })
    
    if buf == 0
        call visidian#debug#error('SEARCH', 'Failed to start terminal for fzf')
        echohl ErrorMsg
        echo "Failed to start search terminal"
        echohl None
        let s:search_active = 0
        return
    endif
    
    call visidian#debug#debug('SEARCH', 'System FZF search started successfully')
endfunction

"FUNCTION: Vim search
function! s:vim_search(query)
    call visidian#debug#debug('SEARCH', 'Starting Vim built-in search...')
    
    " Use vimgrep with ripgrep
    try
        execute 'silent! grep! ' . shellescape(a:query) . ' ' . g:visidian_vault_path . '/**/*.md'
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
