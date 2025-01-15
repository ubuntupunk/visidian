"These are the sync helper functions called by visidian#sync in
"autoload/visidian.vim

function! visidian#sync#sync()
    if !exists('g:visidian_vault_path') || g:visidian_vault_path == ''
        echoerr "No vault path set. Please set a vault first."
        return
    endif

    if !exists('g:visidian_sync_method')
        let g:visidian_sync_method = inputlist(['Choose sync method:', '1. Git', '2. Rsync', '3. Syncthing'])
        if g:visidian_sync_method == 0
            echo "Sync method not selected."
            return
        endif
    endif

    if g:visidian_sync_method == 1 " Git
        if !exists('g:visidian_git_repo_url')
            let g:visidian_git_repo_url = input('Enter Git repository URL: ')
        endif
        call s:sync_git()
    elseif g:visidian_sync_method == 2 " Rsync
        if !exists('g:visidian_rsync_target')
            let g:visidian_rsync_target = input('Enter Rsync target directory (e.g., user@host:/path/to/dir): ')
        endif
        call s:sync_rsync()
    elseif g:visidian_sync_method == 3 " Syncthing
        echo "Syncthing sync is assumed to be running as a background service. Please ensure it's configured."
        " Note: Syncthing typically doesn't need manual sync commands if properly set up
        echo "Syncing with Syncthing..."
    else
        echoerr "Invalid sync method selected."
    endif
endfunction

function! s:sync_git()
    let cmd = [
        \ 'cd ' . shellescape(g:visidian_vault_path),
        \ 'git add .',
        \ 'git commit -m "Sync via Visidian"',
        \ 'git push -u origin main'
    \ ]

    " Check if the directory is a Git repo
    if !isdirectory(g:visidian_vault_path . '.git')
        echo "Initializing new Git repository..."
        call add(cmd, 'git init')
        call add(cmd, 'git remote add origin ' . shellescape(g:visidian_git_repo_url))
        call add(cmd, 'git branch -M main')
    endif

    let joined_cmd = join(cmd, ' && ')
    let result = system(joined_cmd)
    if v:shell_error == 0
        echo "Git sync completed."
    else
        echoerr "Git sync failed: " . result
    endif
endfunction

function! s:sync_rsync()
    let cmd = 'rsync -avz --delete ' . shellescape(g:visidian_vault_path) . ' ' . shellescape(g:visidian_rsync_target)
    let result = system(cmd)
    if v:shell_error == 0
        echo "Rsync sync completed."
    else
        echoerr "Rsync sync failed: " . result
    endif
endfunction
