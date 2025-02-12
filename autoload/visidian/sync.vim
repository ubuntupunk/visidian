"These are the sync helper functions called by visidian#sync in
"autoload/visidian.vim

"FUNCTION: Check if path is within vault
function! s:is_within_vault(path)
    let vault_path = fnamemodify(g:visidian_vault_path, ':p')
    let check_path = fnamemodify(a:path, ':p')
    return check_path =~# '^' . escape(vault_path, '/\')
endfunction

"FUNCTION: Generate Deploy Key and Config
function! s:setup_git_deploy(owner, repo)
    " Ensure we have a vault path
    if !exists('g:visidian_vault_path') || g:visidian_vault_path == ''
        throw 'Vault path not set'
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

    " Generate SSH key
    call visidian#debug#info('SYNC', 'Generating SSH key at ' . key_path)
    let keygen_cmd = 'ssh-keygen -t ed25519 -N "" -f ' . shellescape(key_path)
    if force_overwrite
        let cmd = 'yes y | ' . keygen_cmd
    else
        let cmd = keygen_cmd
    endif

    let output = system(cmd)
    if v:shell_error
        throw 'Failed to generate SSH key: ' . output
    endif

    " Set permissions
    call setfperm(key_path, "600")
    call setfperm(pub_key_path, "644")

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
        call setfperm(ssh_config, "600")
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

"FUNCTION: Initialize Git Repository
function! s:init_git_repo(git_url)
    " Ensure we're initializing in the vault directory
    if !exists('g:visidian_vault_path') || g:visidian_vault_path == ''
        throw 'Vault path not set'
    endif

    let vault_path = fnamemodify(g:visidian_vault_path, ':p')
    
    " Check if .git already exists in vault
    if isdirectory(vault_path . '.git')
        throw 'Git repository already exists in vault'
    endif

    let init_cmd = [
        \ 'cd ' . shellescape(vault_path),
        \ 'git init',
        \ 'git config --local core.excludesfile ' . shellescape(vault_path . '.gitignore')
    \ ]

    if a:git_url != ''
        call add(init_cmd, 'git remote add origin ' . shellescape(a:git_url))
        call add(init_cmd, 'git branch -M main')
    endif
    
    for cmd in init_cmd
        let output = system(cmd)
        if v:shell_error
            throw 'Failed to initialize repository: ' . output
        endif
    endfor

    " Create default .gitignore if it doesn't exist
    let gitignore_path = vault_path . '.gitignore'
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
        call setfperm(gitignore_path, "644")
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

    let vault_path = fnamemodify(g:visidian_vault_path, ':p')
    
    " Ensure vault directory exists
    if !isdirectory(vault_path)
        call visidian#debug#error('SYNC', 'Vault directory does not exist')
        echohl ErrorMsg
        echo "Vault directory does not exist: " . vault_path
        echohl None
        return
    endif

    if !exists('g:visidian_sync_method')
        call visidian#debug#info('SYNC', 'No sync method set, prompting user')
        let g:visidian_sync_method = inputlist(['Choose sync method:', '1. Git', '2. Rsync', '3. Other'])
        if g:visidian_sync_method == 0
            call visidian#debug#info('SYNC', 'User cancelled sync method selection')
            echo "Sync method not selected."
            return
        endif
    endif

    call visidian#debug#debug('SYNC', 'Using sync method: ' . g:visidian_sync_method)

    if g:visidian_sync_method == 1 " Git
        " Ask user for Git setup preference
        let setup_choice = inputlist([
            \ 'Choose Git setup option:',
            \ '1. Initialize empty repository only',
            \ '2. Automatic setup with GitHub'
        \ ])

        if setup_choice == 1
            " Initialize empty repository
            try
                call s:init_git_repo('')
                echo "Empty Git repository initialized in vault. Add remote URL manually when ready."
            catch
                call visidian#debug#error('SYNC', v:exception)
                echohl ErrorMsg | echo v:exception | echohl None
            endtry
        elseif setup_choice == 2
            " Automatic GitHub setup
            try
                " Get GitHub details
                let owner = input('Enter GitHub username: ')
                if owner == '' | throw 'GitHub username required' | endif
                
                let repo = input('Enter repository name: ')
                if repo == '' | throw 'Repository name required' | endif
                
                " Validate repository name
                if repo =~ '[/\\]'
                    throw 'Repository name cannot contain slashes'
                endif

                " Generate deploy key and get setup instructions
                let setup = s:setup_git_deploy(owner, repo)
                
                " Initialize repository with the generated URL
                call s:init_git_repo(setup.git_url)
                
                echo "Repository initialized successfully with deploy key configuration."
            catch
                call visidian#debug#error('SYNC', v:exception)
                echohl ErrorMsg | echo v:exception | echohl None
            endtry
        endif
    elseif g:visidian_sync_method == 2 " Rsync
        if !exists('g:visidian_rsync_target')
            call visidian#debug#info('SYNC', 'No Rsync target set, prompting user')
            let g:visidian_rsync_target = input('Enter Rsync target directory (e.g., user@host:/path/to/dir): ')
        endif
        call s:sync_rsync()
    elseif g:visidian_sync_method == 3 " Other
        call visidian#debug#info('SYNC', 'Using other sync method')
        echo "Other sync methods can be configured in your vimrc."
    else
        call visidian#debug#error('SYNC', 'Invalid sync method: ' . g:visidian_sync_method)
        echohl ErrorMsg
        echo "Invalid sync method selected."
        echohl None
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
