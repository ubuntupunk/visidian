"These are the sync helper functions called by visidian#sync in
"autoload/visidian.vim

"FUNCTION: Check if path is within vault
function! s:is_within_vault(path)
    let vault_path = fnamemodify(g:visidian_vault_path, ':p')
    let check_path = fnamemodify(a:path, ':p')
    return check_path =~# '^' . escape(vault_path, '/\')
endfunction

"FUNCTION: Initialize Git Repository
function! s:init_git_repo(git_url)
    " Ensure we're initializing in the vault directory
    if !exists('g:visidian_vault_path') || g:visidian_vault_path == ''
        throw 'Vault path not set. Please set your vault first using :VisidianSetVault'
    endif

    let vault_path = fnamemodify(g:visidian_vault_path, ':p')
    
    " Ensure we're in the vault directory
    let cwd = getcwd()
    if cwd != vault_path
        execute 'lcd ' . fnameescape(vault_path)
    endif
    
    " Check if .git already exists in vault
    if isdirectory(vault_path . '/.git')
        throw 'Git repository already exists in vault'
    endif

    let init_cmd = [
        \ 'git init',
        \ 'git config --local core.excludesfile ' . shellescape(vault_path . '/.gitignore')
    \ ]

    if a:git_url != ''
        call add(init_cmd, 'git remote add origin ' . shellescape(a:git_url))
        " Only rename branch after first commit
        call add(init_cmd, 'git add .')
        call add(init_cmd, 'git commit -m "Initial commit"')
        call add(init_cmd, 'git branch -M main')
    endif
    
    for cmd in init_cmd
        let output = system(cmd)
        if v:shell_error
            if cmd =~ '^git commit' && output =~ 'nothing to commit'
                continue  " Skip commit error if no files
            endif
            throw 'Failed to initialize repository: ' . output
        endif
    endfor

    " Create default .gitignore if it doesn't exist
    let gitignore_path = vault_path . '/.gitignore'
    if !filereadable(gitignore_path)
        let gitignore_content = [
            \ '# Visidian default gitignore',
            \ '.DS_Store',
            \ 'Thumbs.db',
            \ '*.swp',
            \ '*.swo',
            \ '*~',
            \ '.git/',
            \ '.obsidian/',
            \ '.trash/'
        \ ]
        call writefile(gitignore_content, gitignore_path)
        call setfperm(gitignore_path, "rw-r--r--")  " 644 in rwx format
    endif
endfunction

"FUNCTION: Show Deploy Instructions
function! s:show_deploy_instructions(pub_key, owner, repo)
    " Create buffer with instructions
    new
    setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
    
    " Set buffer name
    execute 'file Visidian_Deploy_Instructions'
    
    call append(0, [
        \ '=== Visidian Git Setup Instructions ===',
        \ '',
        \ '1. Copy this deploy key and add it to your GitHub repository:',
        \ '   ' . a:pub_key,
        \ '',
        \ '2. Visit this URL to add the deploy key:',
        \ '   https://github.com/' . a:owner . '/' . a:repo . '/settings/keys/new',
        \ '',
        \ '3. Make sure to:',
        \ '   - Give it a descriptive title (e.g., "Visidian Deploy Key")',
        \ '   - Check "Allow write access" if you want to push changes',
        \ '',
        \ '4. Click "Add deploy key"',
        \ '',
        \ '5. Press any key to continue with repository initialization...'
    \ ])
    
    " Format buffer
    normal! gg
    setlocal readonly
    setlocal nomodifiable
    
    " Create popup with notification
    let popup_lines = [
        \ ' Deploy Key Setup Required ',
        \ '',
        \ ' Please check the Visidian_Deploy_Instructions ',
        \ ' buffer to complete the repository setup. ',
        \ '',
        \ ' Press any key to close this popup... '
    \ ]
    
    " Calculate popup dimensions
    let max_width = max(map(copy(popup_lines), 'len(v:val)'))
    let height = len(popup_lines)
    
    " Show centered popup
    call popup_create(popup_lines, {
        \ 'title': ' Visidian ',
        \ 'padding': [1,1,1,1],
        \ 'pos': 'center',
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'width': max_width + 2,
        \ 'close': 'click',
        \ 'highlight': 'Normal',
        \ 'borderhighlight': ['MoreMsg']
        \ })
    
    redraw
    call getchar()
endfunction

"FUNCTION: Generate Deploy Key and Config
function! s:setup_git_deploy(owner, repo)
    " Ensure we have a vault path
    if !exists('g:visidian_vault_path') || g:visidian_vault_path == ''
        throw 'Vault path not set. Please set your vault first using :VisidianSetVault'
    endif
    
    let vault_path = fnamemodify(g:visidian_vault_path, ':p')
    let ssh_dir = expand('~/.ssh')
    
    " Check for .ssh directory
    if !isdirectory(ssh_dir)
        throw 'SSH directory not found. Please create ~/.ssh directory with proper permissions (700) first.'
    endif

    let key_name = 'id_rsa.visidian_' . a:repo
    let key_path = ssh_dir . '/' . key_name
    let force_overwrite = 0
    
    " Handle existing key
    if filereadable(key_path)
        let choice = inputlist([
            \ 'SSH key already exists: ' . key_path,
            \ '1. Overwrite existing key',
            \ '2. Use alternate name',
            \ '3. Cancel'
        \ ])

        if choice == 1
            let force_overwrite = 1
        elseif choice == 2
            let alt_name = input('Enter alternate key name (without path): ')
            if alt_name == ''
                throw 'Key name required'
            endif
            let key_name = alt_name
            let key_path = ssh_dir . '/' . key_name
        elseif choice == 3
            throw 'Operation cancelled by user'
        endif
    endif

    let pub_key_path = key_path . '.pub'
    let ssh_config = ssh_dir . '/config'

    " Check if we're on Windows
    let s:is_windows = has('win32') || has('win64')

    " Function to set SSH key permissions based on OS
    function! s:set_ssh_key_permissions(key_path) abort
        if s:is_windows
            " Windows doesn't use chmod, but we can use icacls to set permissions
            " This ensures only the current user has access to the private key
            let cmd = 'icacls "' . a:key_path . '" /inheritance:r /grant:r "%USERNAME%":F'
            let output = system(cmd)
            if v:shell_error
                call visidian#debug#error('SYNC', "Failed to set Windows permissions for SSH key: " . output)
                return 0
            endif
        else
            " Unix/Linux permissions using rwx format
            call setfperm(a:key_path, "rw-------")  " 600 in rwx format
            if getfperm(a:key_path) != "rw-------"
                call visidian#debug#error('SYNC', "Failed to set Unix permissions for SSH key")
                return 0
            endif
        endif
        return 1
    endfunction

    " Function to generate SSH key based on OS
    function! s:generate_ssh_key(key_path, email) abort
        let key_dir = fnamemodify(a:key_path, ':h')
        
        " Create .ssh directory if it doesn't exist
        if !isdirectory(key_dir)
            if s:is_windows
                call mkdir(key_dir, 'p')
            else
                call mkdir(key_dir, 'p', 0700)  " rwx------ format
            endif
        endif

        " Generate SSH key
        let cmd = 'ssh-keygen -t ed25519 -C ' . shellescape(a:email) . ' -f ' . shellescape(a:key_path) . ' -N ""'
        let output = system(cmd)
        if v:shell_error
            call visidian#debug#error('SYNC', "Failed to generate SSH key: " . output)
            return 0
        endif

        " Set proper permissions
        if !s:set_ssh_key_permissions(a:key_path)
            return 0
        endif

        " Set permissions for public key
        if s:is_windows
            let pub_cmd = 'icacls "' . a:key_path . '.pub" /inheritance:r /grant:r "%USERNAME%":F'
            let output = system(pub_cmd)
            if v:shell_error
                call visidian#debug#error('SYNC', "Failed to set Windows permissions for public key: " . output)
                return 0
            endif
        else
            " Set public key permissions using rwx format
            call setfperm(a:key_path . '.pub', "rw-r--r--")  " 644 in rwx format
            if getfperm(a:key_path . '.pub') != "rw-r--r--"
                call visidian#debug#error('SYNC', "Failed to set Unix permissions for public key")
                return 0
            endif
        endif

        return 1
    endfunction

    " Generate SSH key
    call visidian#debug#info('SYNC', 'Generating SSH key at ' . key_path)
    if !s:generate_ssh_key(key_path, 'visidian@localhost')
        throw 'Failed to generate SSH key'
    endif

    " Create SSH config entry
    let host_alias = 'github.com-visidian_' . a:repo
    let config_entry = "\n# Visidian Key Generated on " . strftime('%Y-%m-%d at %H:%M:%S') . "\n"
    let config_entry .= "Host " . host_alias . "\n"
    let config_entry .= "    HostName github.com\n"
    let config_entry .= "    User git\n"
    let config_entry .= "    IdentityFile " . key_path . "\n"

    " Update SSH config
    if !filereadable(ssh_config)
        call writefile([config_entry], ssh_config)
        call setfperm(ssh_config, "rw-------")  " 600 in rwx format
    else
        " Check if host alias already exists
        let config_content = readfile(ssh_config)
        let host_pattern = '^Host\s\+' . host_alias . '$'
        let host_exists = 0
        
        for line in config_content
            if line =~ host_pattern
                let host_exists = 1
                break
            endif
        endfor

        if !host_exists
            call writefile([config_entry], ssh_config, 'a')
        endif
    endif

    " Construct Git URL with alias
    let git_url = 'git@' . host_alias . ':' . a:owner . '/' . a:repo . '.git'

    " Create buffer with instructions
    new
    setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
    call append(0, [
        \ '=== Visidian Git Setup Instructions ===',
        \ '',
        \ '1. Copy this deploy key and add it to your GitHub repository:',
        \ '   ' . readfile(pub_key_path)[0],
        \ '',
        \ '2. Visit this URL to add the deploy key:',
        \ '   https://github.com/' . a:owner . '/' . a:repo . '/settings/keys/new',
        \ '',
        \ '3. Make sure to:',
        \ '   - Give it a descriptive title (e.g., "Visidian Deploy Key")',
        \ '   - Check "Allow write access" if you want to push changes',
        \ '',
        \ '4. Click "Add deploy key"',
        \ '',
        \ '5. Press any key to continue with repository initialization...'
    \ ])
    normal! gg
    redraw
    call getchar()
    bwipeout

    return {
        \ 'key_path': key_path,
        \ 'git_url': git_url
    \ }
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

    let vault_path = fnamemodify(g:visidian_vault_path, ':p')
    
    " Ensure vault directory exists
    if !isdirectory(vault_path)
        call visidian#debug#error('SYNC', 'Vault directory does not exist')
        echohl ErrorMsg
        echo "Vault directory does not exist: " . vault_path
        echohl None
        return
    endif

    " Get sync method from user if not set
    if !exists('g:visidian_sync_method')
        call visidian#debug#info('SYNC', 'No sync method set, prompting user')
        let g:visidian_sync_method = inputlist(['Choose sync method:', 
            \ '1. Git', 
            \ '2. Git Annex', 
            \ '3. Rsync'])
    endif

    " Handle sync based on method
    if g:visidian_sync_method == 1 " Git
        if !exists('g:visidian_git_repo_url')
            call visidian#debug#info('SYNC', 'No Git repository URL set, prompting user')
            let g:visidian_git_repo_url = input('Enter Git repository URL: ')
        endif
        call s:setup_git_sync()
    elseif g:visidian_sync_method == 2 " Git Annex
        if !exists('g:visidian_git_repo_url')
            call visidian#debug#info('SYNC', 'No Git repository URL set, prompting user')
            let g:visidian_git_repo_url = input('Enter Git repository URL: ')
        endif
        
        " Initialize git-annex if needed
        if !isdirectory(g:visidian_vault_path . '/.git/annex')
            if !visidian#sync#annex#init()
                return 0
            endif
        endif
        
        " Perform sync
        call visidian#sync#annex#sync()
    elseif g:visidian_sync_method == 3 " Rsync
        if !exists('g:visidian_rsync_target')
            call visidian#debug#info('SYNC', 'No Rsync target set, prompting user')
            let g:visidian_rsync_target = input('Enter Rsync target directory (e.g., user@host:/path/to/dir): ')
        endif
        call s:sync_rsync()
    else
        call visidian#debug#error('SYNC', 'Invalid sync method: ' . g:visidian_sync_method)
        return 0
    endif
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
        echo "Rsync completed successfully"
    catch
        call visidian#debug#error('SYNC', 'Rsync failed: ' . v:exception)
        echohl ErrorMsg
        echo "Rsync failed: " . v:exception
        echohl None
    endtry
endfunction

" FUNCTIONS TO START AND STOP THE AUTO-SYNC TIMER 

" First Version check for auto-sync functionality
if v:version >= 800
    function! visidian#sync#toggle_auto_sync()
        " Ensure vault is set up
        if !exists('g:visidian_vault_path') || g:visidian_vault_path == ''
            call visidian#debug#error('SYNC', "No vault path set. Please set your vault first using :VisidianSetVault")
            return
        endif

        " Check if git repo exists
        if !isdirectory(g:visidian_vault_path . '/.git')
            call visidian#debug#error('SYNC', "Git repository not initialized. Please set up sync first using :VisidianSync")
            return
        endif

        if exists('s:auto_sync_timer')
            call timer_stop(s:auto_sync_timer)
            unlet s:auto_sync_timer
            call visidian#debug#info('SYNC', "Auto-sync stopped.")
            echo "Auto-sync disabled."
        else
            let s:auto_sync_timer = timer_start(3600000, function('s:AutoSyncCallback'), {'repeat': -1})
            call visidian#debug#info('SYNC', "Auto-sync started. Syncing every hour.")
            echo "Auto-sync enabled. Syncing every hour."
        endif
    endfunction

    function! s:AutoSyncCallback(timer)
        call visidian#sync#sync()
        call visidian#debug#info('SYNC', "Auto-sync performed at " . strftime('%H:%M:%S'))
    endfunction
else
    " Fallback for versions < 8.0
    let s:last_sync_time = 0
    function! s:CheckForSync()
        " Ensure vault is set up
        if !exists('g:visidian_vault_path') || g:visidian_vault_path == ''
            return
        endif

        " Check if git repo exists
        if !isdirectory(g:visidian_vault_path . '/.git')
            return
        endif

        if !exists('s:last_sync_time') || localtime() - s:last_sync_time > 3600 " 3600 seconds = 1 hour
            let s:last_sync_time = localtime()
            call visidian#sync#sync()
            call visidian#debug#info('SYNC', "Periodic sync performed at " . strftime('%H:%M:%S'))
        endif
    endfunction

    augroup VisidianSyncAuto
        autocmd!
        autocmd CursorHold * call s:CheckForSync()
    augroup END
endif
