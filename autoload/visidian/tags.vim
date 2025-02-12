" Tags management for Visidian
" Maintainer: David Robert Lewis

function! visidian#tags#complete(ArgLead, CmdLine, CursorPos) abort
    let l:options = ['all', 'headers', 'links', 'tasks']
    return filter(l:options, 'v:val =~ "^" . a:ArgLead')
endfunction

function! visidian#tags#generate(...) abort
    let l:type = a:0 > 0 ? a:1 : 'all'
    let l:vault_dir = visidian#get_vault_dir()
    let l:tags_file = l:vault_dir . '/tags'
    
    " Define tag patterns based on type
    let l:patterns = {
        \ 'all': ['*.md'],
        \ 'headers': ['^#\+\s\+.*$'],
        \ 'links': ['\[\[.*\]\]', '\[.*\](.*)', '^tags:.*$'],
        \ 'tasks': ['^\s*- \[ \].*$', '^\s*- \[x\].*$']
        \ }

    " Get patterns for requested type
    let l:active_patterns = get(l:patterns, l:type, l:patterns.all)

    " Build ctags command
    let l:cmd = ['ctags', '-f', l:tags_file, '--recurse']
    
    " Add language definition for markdown
    let l:cmd += ['--langdef=markdown', '--languages=markdown']
    let l:cmd += ['--langmap=markdown:.md']

    " Add patterns based on type
    for pattern in l:active_patterns
        let l:cmd += ['--regex-markdown=' . shellescape('/'.pattern.'/\0/t,tag,tags/')]
    endfor

    " Add vault directory
    let l:cmd += [l:vault_dir]

    " Execute command
    let l:output = system(join(l:cmd, ' '))
    
    if v:shell_error
        echoerr 'Failed to generate tags: ' . l:output
        return
    endif

    " Reload tags file
    execute 'set tags=' . l:tags_file
    echomsg 'Generated tags for type: ' . l:type
endfunction
