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

" Function: visidian#tags#extract_tags
" Description: Extract tags from a file's content
" Parameters:
"   - content: List of lines to extract tags from
" Returns: List of tags found in the content
function! visidian#tags#extract_tags(content) abort
    call visidian#debug#debug('TAGS', 'Extracting tags from content')
    let tags = []
    let in_yaml = 0
    let yaml_end = 0
    
    " First check YAML frontmatter for tags
    for i in range(len(a:content))
        let line = a:content[i]
        
        " Check for YAML start/end markers
        if i == 0 && line =~# '^---\s*$'
            call visidian#debug#debug('TAGS', 'Found YAML start marker')
            let in_yaml = 1
            continue
        elseif in_yaml && line =~# '^---\s*$'
            call visidian#debug#debug('TAGS', 'Found YAML end marker')
            let yaml_end = i
            break
        endif
        
        if in_yaml && line =~# '^\s*tags:'
            call visidian#debug#debug('TAGS', 'Found tags field in YAML')
            " Handle array format: tags: [tag1, tag2]
            if line =~# '\[.*\]'
                let tag_list = matchstr(line, '^\s*tags:\s*\[\zs.*\ze\]')
                let yaml_tags = split(tag_list, ',\s*')
                call extend(tags, yaml_tags)
                call visidian#debug#debug('TAGS', 'Added ' . len(yaml_tags) . ' tags from YAML array')
            else
                " Handle multi-line format:
                " tags:
                "   - tag1
                "   - tag2
                let j = i + 1
                while j < len(a:content) && a:content[j] =~# '^\s*-\s'
                    let tag = matchstr(a:content[j], '^\s*-\s*\zs.*\ze\s*$')
                    call add(tags, tag)
                    call visidian#debug#debug('TAGS', 'Added tag from YAML list: ' . tag)
                    let j += 1
                endwhile
            endif
        endif
    endfor
    
    " Then look for inline tags (#tag)
    let tag_pattern = '#[A-Za-z][A-Za-z0-9_-]*'
    for line in a:content
        let start = 0
        while 1
            let match = matchstrpos(line, tag_pattern, start)
            if match[1] == -1
                break
            endif
            let tag = match[0][1:] " Remove the # prefix
            if index(tags, tag) == -1
                call add(tags, tag)
                call visidian#debug#debug('TAGS', 'Found inline tag: ' . tag)
            endif
            let start = match[2]
        endwhile
    endfor
    
    call visidian#debug#info('TAGS', 'Found ' . len(tags) . ' unique tags')
    return tags
endfunction

" Function: visidian#tags#get_tags
" Description: Get all tags from a file
" Parameters:
"   - file_path: Path to the file to get tags from
" Returns: List of tags found in the file
function! visidian#tags#get_tags(file_path) abort
    call visidian#debug#debug('TAGS', 'Getting tags from file: ' . a:file_path)
    
    if !filereadable(a:file_path)
        call visidian#debug#error('TAGS', 'Cannot read file: ' . a:file_path)
        return []
    endif
    
    let content = readfile(a:file_path)
    call visidian#debug#debug('TAGS', 'Read ' . len(content) . ' lines from file')
    
    return visidian#tags#extract_tags(content)
endfunction

" Function: visidian#tags#find_files_with_tag
" Description: Find all files that contain a specific tag
" Parameters:
"   - tag: Tag to search for
" Returns: List of file paths that contain the tag
function! visidian#tags#find_files_with_tag(tag) abort
    call visidian#debug#debug('TAGS', 'Searching for files with tag: ' . a:tag)
    
    if !exists('g:visidian_vault_path')
        call visidian#debug#error('TAGS', 'g:visidian_vault_path not set')
        return []
    endif
    
    let files = []
    let markdown_files = globpath(g:visidian_vault_path, '**/*.md', 0, 1)
    call visidian#debug#debug('TAGS', 'Found ' . len(markdown_files) . ' markdown files to search')
    
    for file in markdown_files
        let tags = visidian#tags#get_tags(file)
        if index(tags, a:tag) >= 0
            call add(files, file)
            call visidian#debug#debug('TAGS', 'Found tag in file: ' . file)
        endif
    endfor
    
    call visidian#debug#info('TAGS', 'Found ' . len(files) . ' files with tag: ' . a:tag)
    return files
endfunction

" Function: visidian#tags#get_all_tags
" Description: Get all unique tags used in the vault
" Returns: List of all unique tags
function! visidian#tags#get_all_tags() abort
    call visidian#debug#debug('TAGS', 'Getting all tags from vault')
    
    if !exists('g:visidian_vault_path')
        call visidian#debug#error('TAGS', 'g:visidian_vault_path not set')
        return []
    endif
    
    let all_tags = {}
    let markdown_files = globpath(g:visidian_vault_path, '**/*.md', 0, 1)
    call visidian#debug#debug('TAGS', 'Found ' . len(markdown_files) . ' markdown files to process')
    
    for file in markdown_files
        let tags = visidian#tags#get_tags(file)
        for tag in tags
            let all_tags[tag] = get(all_tags, tag, 0) + 1
            call visidian#debug#debug('TAGS', 'Found tag occurrence: ' . tag)
        endfor
    endfor
    
    let tag_list = keys(all_tags)
    call visidian#debug#info('TAGS', 'Found ' . len(tag_list) . ' unique tags across vault')
    return tag_list
endfunction
