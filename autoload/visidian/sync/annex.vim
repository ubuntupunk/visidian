" Git Annex integration for Visidian
" Maintainer: ubuntupunk

" Initialize git-annex in the vault
function! visidian#sync#annex#init() abort
    if !executable('git-annex')
        call visidian#debug#error('SYNC', 'git-annex not found. Please install it first.')
        return 0
    endif

    try
        " Initialize git-annex
        let cmd = 'cd ' . shellescape(g:visidian_vault_path) . ' && git annex init "Visidian Vault"'
        let output = system(cmd)
        if v:shell_error
            throw 'Failed to initialize git-annex: ' . output
        endif

        " Configure git-annex for typical knowledge management use
        let config_cmds = [
            \ 'git config annex.largefiles "largerthan=100kb"',  " Only annex files larger than 100KB
            \ 'git config annex.addunlocked true',              " Add files in unlocked mode by default
            \ 'git config annex.thin true'                      " Save disk space in working tree
        \ ]

        for config_cmd in config_cmds
            let cmd = 'cd ' . shellescape(g:visidian_vault_path) . ' && ' . config_cmd
            let output = system(cmd)
            if v:shell_error
                throw 'Failed to configure git-annex: ' . output
            endif
        endfor

        call visidian#debug#info('SYNC', 'git-annex initialized successfully')
        return 1
    catch
        call visidian#debug#error('SYNC', v:exception)
        return 0
    endtry
endfunction

" Sync using git-annex
function! visidian#sync#annex#sync() abort
    if !executable('git-annex')
        call visidian#debug#error('SYNC', 'git-annex not found. Please install it first.')
        return 0
    endif

    try
        let cmds = [
            \ 'git annex add .',           " Add new files to annex
            \ 'git add .',                 " Add remaining files to git
            \ 'git commit -m "Update vault content ' . strftime('%Y-%m-%d %H:%M:%S') . '"',
            \ 'git annex sync --content'   " Sync both metadata and content
        \ ]

        for cmd in cmds
            let full_cmd = 'cd ' . shellescape(g:visidian_vault_path) . ' && ' . cmd
            let output = system(full_cmd)
            if v:shell_error
                throw 'Command failed: ' . cmd . ', Error: ' . output
            endif
        endfor

        call visidian#debug#info('SYNC', 'git-annex sync completed successfully')
        return 1
    catch
        call visidian#debug#error('SYNC', v:exception)
        return 0
    endtry
endfunction

" Get status of annexed files
function! visidian#sync#annex#status() abort
    if !executable('git-annex')
        call visidian#debug#error('SYNC', 'git-annex not found. Please install it first.')
        return ''
    endif

    try
        let cmd = 'cd ' . shellescape(g:visidian_vault_path) . ' && git annex status'
        let output = system(cmd)
        if v:shell_error
            throw 'Failed to get git-annex status: ' . output
        endif
        return output
    catch
        call visidian#debug#error('SYNC', v:exception)
        return ''
    endtry
endfunction

" Configure a new remote for git-annex
function! visidian#sync#annex#add_remote(name, url, type) abort
    if !executable('git-annex')
        call visidian#debug#error('SYNC', 'git-annex not found. Please install it first.')
        return 0
    endif

    try
        " Add the git remote first
        let cmd = 'cd ' . shellescape(g:visidian_vault_path) . ' && git remote add ' . 
            \ shellescape(a:name) . ' ' . shellescape(a:url)
        let output = system(cmd)
        if v:shell_error
            throw 'Failed to add git remote: ' . output
        endif

        " Enable the remote in git-annex
        let cmd = 'cd ' . shellescape(g:visidian_vault_path) . 
            \ ' && git annex enableremote ' . shellescape(a:name)
        let output = system(cmd)
        if v:shell_error
            throw 'Failed to enable remote in git-annex: ' . output
        endif

        " Configure the remote type if specified
        if !empty(a:type)
            let cmd = 'cd ' . shellescape(g:visidian_vault_path) . 
                \ ' && git annex wanted ' . shellescape(a:name) . ' ' . shellescape(a:type)
            let output = system(cmd)
            if v:shell_error
                throw 'Failed to configure remote type: ' . output
            endif
        endif

        call visidian#debug#info('SYNC', 'git-annex remote added successfully')
        return 1
    catch
        call visidian#debug#error('SYNC', v:exception)
        return 0
    endtry
endfunction
