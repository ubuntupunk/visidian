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
    if g:visidian_vault_path == ''
        call visidian#debug#error('SEARCH', 'No vault path set')
        echohl ErrorMsg
        echo "No vault path set. Please create or set a vault first."
        echohl None
        return
    endif

    call visidian#debug#debug('SEARCH', 'Starting search...')

    let query = input("Enter search query: ")
    if empty(query)
        call visidian#debug#info('SEARCH', 'Empty search query')
        echo "No query provided."
        return
    endif

    call visidian#debug#debug('SEARCH', 'Search query: ' . query)
    let s:search_active = 1

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
    let reload_command = command . '{q}'
    
    try
        call fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(), 0)
        call visidian#debug#debug('SEARCH', 'FZF search started successfully')
    catch
        call visidian#debug#error('SEARCH', 'FZF search failed: ' . v:exception)
        echohl ErrorMsg
        echo "FZF search failed: " . v:exception
        echohl None
        let s:search_active = 0
    endtry
endfunction

"FUNCTION: System FZF search
function! s:system_fzf_search(query)
    call visidian#debug#debug('SEARCH', 'Starting system FZF search...')
    
    let command = 'find ' . shellescape(g:visidian_vault_path) . ' -type f -name "*.md" | '
    let command .= 'xargs rg --column --line-number --no-heading --color=always --smart-case '
    let command .= shellescape(a:query)
    
    try
        call system(command)
        call visidian#debug#debug('SEARCH', 'System FZF search started successfully')
    catch
        call visidian#debug#error('SEARCH', 'System FZF search failed: ' . v:exception)
        echohl ErrorMsg
        echo "System FZF search failed: " . v:exception
        echohl None
        let s:search_active = 0
    endtry
endfunction

"FUNCTION: Vim built-in search
function! s:vim_search(query)
    call visidian#debug#debug('SEARCH', 'Starting Vim built-in search...')

    " Escape special characters in the pattern
    let pattern = escape(a:query, '/\*')
    
    try
        execute 'vimgrep /' . pattern . '/j ' . g:visidian_vault_path . '/**/*.md'
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
