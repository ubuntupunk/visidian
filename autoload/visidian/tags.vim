" Tags management for Visidian
" Maintainer: David Robert Lewis
"
" This module provides tag generation, browsing, and navigation functionality.
" It supports various tag types including headers, links, tasks, and YAML fields.
" Tags are stored in the vault directory and can be browsed using a dedicated UI.

" FUNCTION: Complete tag type options for the :VisidianTags command
function! visidian#tags#complete(ArgLead, CmdLine, CursorPos) abort
    let l:options = ['all', 'headers', 'links', 'tasks', 'yaml']
    return filter(l:options, 'v:val =~ "^" . a:ArgLead')
endfunction

" FUNCTION: Generate tags based on type
" Parameters:
"   type - Optional tag type (all, headers, links, tasks, yaml)
function! visidian#tags#generate(...) abort
    if executable('ctags') == 0
        call visidian#debug#error('TAGS', "Ctags not found. Please install ctags:")
        if has('unix')
            call visidian#debug#warn('TAGS', "  - On Ubuntu/Debian: sudo apt-get install universal-ctags")
            call visidian#debug#warn('TAGS', "  - On macOS with Homebrew: brew install universal-ctags")
        elseif has('win32')
            call visidian#debug#warn('TAGS', "  - On Windows with Chocolatey: choco install ctags")
        endif
        return
    endif

    let l:type = a:0 > 0 ? a:1 : 'all'
    let l:vault_dir = visidian#get_vault_dir()
    let l:tags_file = l:vault_dir . '/tags'
    
    " Define tag patterns based on type
    let l:patterns = {
        \ 'all': [
            \ '--regex-markdown=/^#\+\s+(.*)/\1/h,heading/',
            \ '--regex-markdown=/\[\[(.*?)\]\]/\1/l,wikilink/',
            \ '--regex-markdown=/\[(.*?)\]\((.*?)\)/\2/l,mdlink/',
            \ '--regex-markdown=/^>\{3}\s+(.*)/\1/p,pullquote/',
            \ '--regex-markdown=/^\s*- \[ \](.*)/\1/t,task/',
            \ '--regex-markdown=/^\s*- \[x\](.*)/\1/d,done/',
            \ '--regex-markdown=/^---$(.*?)---$/\1/m,metadata/',
            \ '--regex-markdown=/^tags:\s*\[(.*?)\]/\1/y,tags/',
            \ '--regex-markdown=/^tags:\s*\n\s*-(.*)/\1/y,tags/',
            \ ],
        \ 'headers': ['--regex-markdown=/^#\+\s+(.*)/\1/h,heading/'],
        \ 'links': [
            \ '--regex-markdown=/\[\[(.*?)\]\]/\1/l,wikilink/',
            \ '--regex-markdown=/\[(.*?)\]\((.*?)\)/\2/l,mdlink/'
            \ ],
        \ 'tasks': [
            \ '--regex-markdown=/^\s*- \[ \](.*)/\1/t,task/',
            \ '--regex-markdown=/^\s*- \[x\](.*)/\1/d,done/'
            \ ],
        \ 'yaml': [
            \ '--regex-markdown=/^tags:\s*\[(.*?)\]/\1/y,tags/',
            \ '--regex-markdown=/^tags:\s*\n\s*-(.*)/\1/y,tags/',
            \ '--regex-markdown=/^---$(.*?)---$/\1/m,metadata/'
            \ ]
        \ }

    " Get patterns for requested type
    let l:active_patterns = get(l:patterns, l:type, l:patterns.all)

    " Build ctags command
    let l:cmd = ['ctags', '-f', l:tags_file, '--recurse']
    
    " Add language definition for markdown
    let l:cmd += ['--langdef=markdown', '--languages=markdown']
    let l:cmd += ['--langmap=markdown:.md,.markdown']

    " Add patterns
    let l:cmd += l:active_patterns

    " Add vault directory
    let l:cmd += [l:vault_dir]

    call visidian#debug#info('TAGS', 'Generating tags for type: ' . l:type)
    let l:output = system(join(l:cmd, ' '))
    
    if v:shell_error
        call visidian#debug#error('TAGS', 'Failed to generate tags: ' . l:output)
        return
    endif

    " Reload tags file
    execute 'set tags=' . l:tags_file
    call visidian#debug#info('TAGS', 'Tags generated successfully in ' . l:tags_file)
endfunction

" FUNCTION: Browse tags in a dedicated window
function! visidian#tags#browse() abort
    " Open a new vertical split for tag browsing
    vertical new
    setlocal buftype=nofile bufhidden=hide noswapfile nowrap
    setlocal modifiable

    " Name the buffer
    silent file VisidianTags

    let l:vault_dir = visidian#get_vault_dir()
    let l:tags_file = l:vault_dir . '/tags'

    " Get tags from the tags file
    let l:tags = systemlist('cat ' . l:tags_file . ' | sort')

    if empty(l:tags)
        call setline(1, 'No tags found.')
    else
        " Write tags to buffer
        call setline(1, l:tags)
        
        " Syntax matching for different parts of the tag
        syntax match VisidianTagTitle /^[^ \t]\+\ze\t/ 
        syntax match VisidianTagFile /\t\zs[^ \t]\+\ze\t/ 
        syntax match VisidianTagLineNr /\t\zs\d\+\ze;/ 
        syntax match VisidianTagKind /;\zs[^ \t]\+\ze$/ 

        " Link to highlight groups
        highlight link VisidianTagTitle Title
        highlight VisidianTagFile ctermfg=DarkGray guifg=#666666
        highlight VisidianTagLineNr ctermfg=Yellow guifg=#B8BB26
        highlight VisidianTagKind ctermfg=LightBlue guifg=#83A598

        " Set up key mappings for navigation and filtering
        nnoremap <buffer> <silent> <CR> :call visidian#tags#jump()<CR>
        nnoremap <buffer> <silent> / :call visidian#tags#filter()<CR>
        nnoremap <buffer> <silent> q :q<CR>
        nnoremap <buffer> <silent> <C-n> :<C-u>exe "normal! " . v:count1 . "j"<CR>
        nnoremap <buffer> <silent> <C-p> :<C-u>exe "normal! " . v:count1 . "k"<CR>

        " Highlight tags for better readability
        syntax match Tag /^[^ \t]\+\t/ 
        highlight link Tag Title
    endif

    setlocal nomodifiable
endfunction

" FUNCTION: Jump to the tag under cursor
function! visidian#tags#jump() abort
    let l:line = getline('.')
    call visidian#debug#info('TAGS', "Attempting to jump: " . l:line)
    
    if l:line =~ '^!'
        " Handle special cases like image or link tags if needed
        call visidian#debug#warn('TAGS', "Special tag type, not jumpable")
        return
    endif
    
    let l:parts = split(l:line, "\t")
    if len(l:parts) < 3
        call visidian#debug#error('TAGS', "Invalid tag line format")
        return
    endif
    
    let l:tag_name = l:parts[0]
    let l:tag_file = l:parts[1]
    let l:tag_address = substitute(l:parts[2], '[\r\n[:cntrl:]]', '', 'g')
    let l:tag_address = substitute(l:tag_address, '\s\+$', '', '')

    " Check if we have a full path or need to make it relative to the vault
    let l:vault_dir = visidian#get_vault_dir()
    if l:tag_file !~# '^/'
        let l:tag_file = l:vault_dir . '/' . l:tag_file
    endif

    " Make sure Vim knows you have tags
    execute 'set tags+=' . l:vault_dir . '/' . l:tag_file

    " Open the file and jump to the address
    try
        execute 'edit ' . fnameescape(l:tag_file)
        if l:tag_address =~# '^\d\+$'
            execute l:tag_address
        else
            let @/ = substitute(l:tag_address, ';".*', '', '')
            if search(@/, 'w') == 0
                call visidian#debug#warn('TAGS', "Pattern not found: " . @/)
            else
                normal! n
            endif
        endif
    catch /^Vim\%((\a\+)\)\=:E486/
        " Suppress Pattern not found error
    catch /^Vim\%((\a\+)\)\=:E488/
        " Suppress Trailing characters error
    catch
        call visidian#debug#error('TAGS', "Error opening file: " . l:tag_file . " - " . v:exception)
    endtry
endfunction

" FUNCTION: Filter tags by pattern
function! visidian#tags#filter() abort
    setlocal modifiable
    let l:pattern = input('Filter tags: ')
    if empty(l:pattern)
        return
    endif
    
    let l:vault_dir = visidian#get_vault_dir()
    let l:tags_file = l:vault_dir . '/tags'
    
    %d_ " clear current buffer
    let l:tags = systemlist('cat ' . l:tags_file . ' | grep -i "' . escape(l:pattern, '"\') . '" | sort')
    if empty(l:tags)
        call setline(1, "No tags matching '" . l:pattern . "'")
    else
        call setline(1, l:tags)
    endif
    setlocal nomodifiable
endfunction
