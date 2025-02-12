"These are the sync helper functions called by visidian#sync in
"autoload/visidian.vim

"FUNCTION: Check if path is within vault
function! s:is_within_vault(path)
    let vault_path = fnamemodify(g:visidian_vault_path, ':p')
    let check_path = fnamemodify(a:path, ':p')
    return check_path =~# '^' . escape(vault_path, '/\')
endfunction

"FUNCTION: Parse Git URL
function! s:parse_git_url(url)
    let url = a:url
    let parsed = {}

    " Detect URL type and extract repo info
    if url =~# '^git@github\.com-\(visidian_[^:]\+\):\([^/]\+\)/\([^.]\+\)\.git$'
        let parsed.type = 'ssh'
        let parsed.host_alias = matchstr(url, '^git@\zs[^:]\+\ze:')
        let parsed.owner = matchstr(url, ':\zs[^/]\+\ze/')
        let parsed.repo = matchstr(url, '/\zs[^.]\+\ze\.git$')
        let parsed.key_name = matchstr(parsed.host_alias, 'github\.com-\zsvisidian_.\+\ze$')
    elseif url =~# '^https\?://github\.com/\([^/]\+\)/\([^.]\+\)\.git$'
        let parsed.type = 'https'
        let parsed.owner = matchstr(url, '\.com/\zs[^/]\+\ze/')
        let parsed.repo = matchstr(url, '/\zs[^.]\+\ze\.git$')
    else
        throw 'Unsupported Git URL format. For SSH, use the format from generate_deploy_key.sh script.'
    endif

    return parsed
endfunction

"FUNCTION: Setup Git SSH
function! s:setup_git_ssh()
    let url_info = s:parse_git_url(g:visidian_git_repo_url)
    
    " For SSH URLs from our deploy key generator
    if url_info.type == 'ssh'
        " Check if we have a deploy key path
        if !exists('g:visidian_deploy_key')
            " Try to find the key based on repo name
            let default_key = expand('~/.ssh/id_rsa.visidian_' . url_info.repo)
            if filereadable(default_key)
                let g:visidian_deploy_key = default_key
            else
                " Suggest using the generator script
                throw 'Deploy key not found. Please run scripts/generate_deploy_key.sh ' 
                    \ . url_info.owner . ' ' . url_info.repo
            endif
        endif

        " Verify key exists and has correct permissions
        if !filereadable(g:visidian_deploy_key)
            throw 'Deploy key not found at: ' . g:visidian_deploy_key
        endif

        " Check key permissions
        let key_perms = getfperm(g:visidian_deploy_key)
        if key_perms != '600'
            call visidian#debug#warn('SYNC', 'Deploy key has incorrect permissions: ' . key_perms)
            echo "Warning: Deploy key should have 600 permissions for security"
        endif

        " Set up SSH command with deploy key
        let $GIT_SSH_COMMAND = 'ssh -i ' . shellescape(g:visidian_deploy_key) . 
                            \ ' -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new'
    endif
endfunction

"FUNCTION: Sync
function! visidian#sync#sync()
    if !exists('g:visidian_vault_path') || g:visidian_vault_path == ''
        call visidian#debug#error('SYNC', 'No vault path set')
        echohl ErrorMsg
        echo "No vault path set. Please set a vault first."
        echohl None
        return
    endif

    if !exists('g:visidian_sync_method')
        call visidian#debug#info('SYNC', 'No sync method set, prompting user')
        let g:visidian_sync_method = inputlist(['Choose sync method:', '1. Git', '2. Rsync', '3. Syncthing'])
        if g:visidian_sync_method == 0
            call visidian#debug#info('SYNC', 'User cancelled sync method selection')
            echo "Sync method not selected."
            return
        endif
    endif

    call visidian#debug#debug('SYNC', 'Using sync method: ' . g:visidian_sync_method)

    if g:visidian_sync_method == 1 " Git
        if !exists('g:visidian_git_repo_url')
            call visidian#debug#info('SYNC', 'No Git repo URL set, prompting user')
            let g:visidian_git_repo_url = input('Enter Git repository URL (HTTPS or SSH): ')
        endif
        call s:sync_git()
    elseif g:visidian_sync_method == 2 " Rsync
        if !exists('g:visidian_rsync_target')
            call visidian#debug#info('SYNC', 'No Rsync target set, prompting user')
            let g:visidian_rsync_target = input('Enter Rsync target directory (e.g., user@host:/path/to/dir): ')
        endif
        call s:sync_rsync()
    elseif g:visidian_sync_method == 3 " Syncthing
        call visidian#debug#info('SYNC', 'Using Syncthing sync')
        echo "Syncthing sync is assumed to be running as a background service. Please ensure it's configured."
        echo "Syncing with Syncthing..."
    else
        call visidian#debug#error('SYNC', 'Invalid sync method: ' . g:visidian_sync_method)
        echohl ErrorMsg
        echo "Invalid sync method selected."
        echohl None
    endif
endfunction

"FUNCTION: Git
function! s:sync_git()
    call visidian#debug#debug('SYNC', 'Starting Git sync')

    " Check if git is available
    if !executable('git')
        call visidian#debug#error('SYNC', 'Git not found in PATH')
        echohl ErrorMsg
        echo "Git not found. Please install Git first."
        echohl None
        return
    endif

    " Parse Git URL and set up authentication
    try
        let url_info = s:parse_git_url(g:visidian_git_repo_url)
        if url_info.type == 'ssh'
            call s:setup_git_ssh()
        endif
    catch
        call visidian#debug#error('SYNC', 'Failed to setup Git authentication: ' . v:exception)
        echohl ErrorMsg
        echo "Failed to setup Git authentication: " . v:exception
        echohl None
        return
    endif

    let cmd = [
        \ 'cd ' . shellescape(g:visidian_vault_path),
        \ 'git add .',
        \ 'git commit -m "Sync via Visidian"',
        \ 'git push -u origin main'
    \ ]

    " Check if the directory is a Git repo
    if !isdirectory(g:visidian_vault_path . '.git')
        " Ensure we're only initializing within the vault
        if !s:is_within_vault(getcwd())
            call visidian#debug#error('SYNC', 'Must initialize Git repo within vault')
            echohl ErrorMsg
            echo "Git repository must be initialized within the vault directory."
            echohl None
            return
        endif

        call visidian#debug#info('SYNC', 'Initializing new Git repository')
        echo "Initializing new Git repository..."
        
        try
            let init_cmd = [
                \ 'cd ' . shellescape(g:visidian_vault_path),
                \ 'git init',
                \ 'git remote add origin ' . shellescape(g:visidian_git_repo_url),
                \ 'git branch -M main'
            \ ]
            
            for c in init_cmd
                call visidian#debug#trace('SYNC', 'Executing: ' . c)
                let output = system(c)
                if v:shell_error
                    throw 'Command failed: ' . output
                endif
            endfor
            
            call visidian#debug#info('SYNC', 'Git repository initialized successfully')
        catch
            call visidian#debug#error('SYNC', 'Failed to initialize Git repo: ' . v:exception)
            echohl ErrorMsg
            echo "Failed to initialize Git repository: " . v:exception
            echohl None
            return
        endtry
    endif

    " Execute sync commands
    try
        for c in cmd
            call visidian#debug#trace('SYNC', 'Executing: ' . c)
            let output = system(c)
            if v:shell_error
                " Special handling for "nothing to commit" case
                if output =~ 'nothing to commit'
                    call visidian#debug#info('SYNC', 'Nothing to commit')
                    echo "Nothing to commit, working tree clean"
                    continue
                endif
                throw 'Command failed: ' . output
            endif
        endfor
        
        call visidian#debug#info('SYNC', 'Git sync completed successfully')
        echo "Git sync completed successfully"
    catch
        call visidian#debug#error('SYNC', 'Git sync failed: ' . v:exception)
        echohl ErrorMsg
        echo "Git sync failed: " . v:exception
        echohl None
    endtry
endfunction

"FUNCTION: Rsync
function! s:sync_rsync()
    call visidian#debug#debug('SYNC', 'Starting Rsync sync')

    " Check if rsync is available
    if !executable('rsync')
        call visidian#debug#error('SYNC', 'Rsync not found in PATH')
        echohl ErrorMsg
        echo "Rsync not found. Please install rsync first."
        echohl None
        return
    endif

    try
        let cmd = 'rsync -avz --delete ' . 
            \ shellescape(g:visidian_vault_path) . ' ' . 
            \ shellescape(g:visidian_rsync_target)
        
        call visidian#debug#trace('SYNC', 'Executing: ' . cmd)
        let output = system(cmd)
        
        if v:shell_error
            throw 'Rsync failed: ' . output
        endif
        
        call visidian#debug#info('SYNC', 'Rsync completed successfully')
        echo "Rsync sync completed successfully"
    catch
        call visidian#debug#error('SYNC', 'Rsync sync failed: ' . v:exception)
        echohl ErrorMsg
        echo "Rsync sync failed: " . v:exception
        echohl None
    endtry
endfunction
