" Visidian First Start
" Maintainer: ubuntupunk
" License: MIT

function! visidian#start#welcome() abort
    " Create welcome message
    let welcome = [
        \ '   __   ___     _     _ _             ',
        \ '   \ \ / (_)___(_) __| (_) __ _ _ __  ',
        \ '    \ V /| / __| |/ _` | |/ _` | ''_ \ ',
        \ '     | | | \__ \ | (_| | | (_| | | | |',
        \ '     |_| |_|___/_|\__,_|_|\__,_|_| |_|',
        \ '',
        \ '    Welcome to Visidian - Your Vim-based Personal Knowledge Management System',
        \ '    Version: ' . get(g:, 'visidian_version', 'development'),
        \ '',
        \ '    This guide will help you set up Visidian for the first time.',
        \ '    Press any key to continue...'
        \ ]
    
    " Display welcome message in a popup
    let winid = popup_create(welcome, {
        \ 'title': ' Visidian Setup ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'close': 'click',
        \ })
    
    call visidian#debug#info('START', 'Displayed welcome message')
    call getchar()
    call popup_close(winid)
endfunction

function! visidian#start#check_dependencies() abort
    let missing_deps = []
    
    " Check for required plugins
    if !exists('*fzf#run')
        call add(missing_deps, 'fzf.vim - for fuzzy finding')
    endif
    
    if !empty(missing_deps)
        let msg = [
            \ 'Some recommended dependencies are missing:',
            \ ''
            \ ] + missing_deps + [
            \ '',
            \ 'While Visidian will work without these,',
            \ 'installing them will enhance your experience.',
            \ '',
            \ 'Press any key to continue anyway...'
            \ ]
        
        let winid = popup_create(msg, {
            \ 'title': ' Dependencies ',
            \ 'padding': [1,2,1,2],
            \ 'border': [],
            \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
            \ 'pos': 'center',
            \ 'close': 'click',
            \ })
        
        call visidian#debug#info('START', 'Displayed missing dependencies: ' . string(missing_deps))
        call getchar()
        call popup_close(winid)
    endif
endfunction

function! visidian#start#setup_vault() abort
    let msg = [
        \ 'First, lets set up your vault!',
        \ '',
        \ 'A vault is where all your notes will be stored.',
        \ 'You can either create a new vault or use an existing one.',
        \ '',
        \ 'Press:',
        \ '  [n] to create a New vault',
        \ '  [e] to use an Existing folder as vault',
        \ '  [q] to Quit setup'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' Vault Setup ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:vault_filter'),
        \ 'callback': function('s:vault_callback')
        \ })
    
    call visidian#debug#info('START', 'Displayed vault setup options')
endfunction

function! s:vault_filter(winid, key) abort
    if a:key ==# 'n'
        call popup_close(a:winid)
        call visidian#create_vault()
        " Wait for vault creation to complete
        sleep 500m
        if !empty(g:visidian_vault_path)
            call visidian#debug#info('START', 'New vault created successfully')
            return 1
        endif
    elseif a:key ==# 'e'
        call popup_close(a:winid)
        call visidian#choose_vault()
        sleep 500m
        if !empty(g:visidian_vault_path)
            call visidian#debug#info('START', 'Existing vault selected successfully')
            return 1
        endif
    elseif a:key ==# 'q'
        call popup_close(a:winid)
        return 1
    endif
    return 0
endfunction

function! s:vault_callback(id, result) abort
    if empty(g:visidian_vault_path)
        call visidian#debug#error('START', 'Vault setup did not complete successfully')
    else
        call visidian#debug#info('START', 'Vault setup completed successfully')
    endif
endfunction

function! visidian#start#setup_para() abort
    let msg = [
        \ 'Would you like to set up PARA folders?',
        \ '',
        \ 'PARA is an organizational system that helps you',
        \ 'organize your notes into meaningful categories:',
        \ '',
        \ '  Projects - Active tasks and projects',
        \ '  Areas - Long-term responsibilities',
        \ '  Resources - Topics and interests',
        \ '  Archive - Completed and inactive items',
        \ '',
        \ 'Press:',
        \ '  [y] to create PARA folders',
        \ '  [n] to skip this step',
        \ '  [?] to learn more about PARA'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' PARA Setup ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:para_filter'),
        \ })
    
    call visidian#debug#info('START', 'Displayed PARA setup options')
endfunction

function! s:para_filter(winid, key) abort
    if a:key ==# 'y'
        call popup_close(a:winid)
        call visidian#create_para_folders()
        return 1
    elseif a:key ==# 'n'
        call popup_close(a:winid)
        return 1
    elseif a:key ==# '?'
        call popup_close(a:winid)
        call visidian#help#show_para()
        return 1
    endif
    return 0
endfunction

function! visidian#start#import_notes() abort
    let msg = [
        \ 'Would you like to import existing notes?',
        \ '',
        \ 'Visidian can help organize your existing markdown',
        \ 'files into the PARA structure.',
        \ '',
        \ 'Press:',
        \ '  [y] to import and organize notes',
        \ '  [n] to skip this step'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' Import Notes ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:import_filter'),
        \ })
    
    call visidian#debug#info('START', 'Displayed import options')
endfunction

function! s:import_filter(winid, key) abort
    if a:key ==# 'y'
        call popup_close(a:winid)
        call visidian#import_sort()
        return 1
    elseif a:key ==# 'n'
        call popup_close(a:winid)
        return 1
    endif
    return 0
endfunction

function! visidian#start#setup_sync() abort
    let msg = [
        \ 'Would you like to set up note synchronization?',
        \ '',
        \ 'Visidian can help you keep your notes backed up',
        \ 'and synchronized across devices.',
        \ '',
        \ 'Press:',
        \ '  [y] to configure sync settings',
        \ '  [n] to skip this step'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' Sync Setup ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:sync_filter'),
        \ })
    
    call visidian#debug#info('START', 'Displayed sync options')
endfunction

function! s:sync_filter(winid, key) abort
    if a:key ==# 'y'
        call popup_close(a:winid)
        call visidian#sync()
        return 1
    elseif a:key ==# 'n'
        call popup_close(a:winid)
        return 1
    endif
    return 0
endfunction

function! visidian#start#customize() abort
    let msg = [
        \ 'Would you like to customize Visidian?',
        \ '',
        \ 'You can customize various aspects such as:',
        \ '  - Key mappings',
        \ '  - Preview options',
        \ '  - Auto-sync settings',
        \ '  - Status line integration',
        \ '',
        \ 'Press:',
        \ '  [y] to view customization options',
        \ '  [n] to finish setup'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' Customize ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:customize_filter'),
        \ })
    
    call visidian#debug#info('START', 'Displayed customization options')
endfunction

function! s:customize_filter(winid, key) abort
    if a:key ==# 'y'
        call popup_close(a:winid)
        call visidian#setup()
        return 1
    elseif a:key ==# 'n'
        call popup_close(a:winid)
        return 1
    endif
    return 0
endfunction

function! visidian#start#finish() abort
    let msg = [
        \ 'Setup Complete! ',
        \ '',
        \ 'You can now start using Visidian:',
        \ '',
        \ '  - Press \v to open the main menu',
        \ '  - Type :help visidian for documentation',
        \ '  - Visit our GitHub page for updates',
        \ '',
        \ 'Happy note-taking!',
        \ '',
        \ 'Press any key to close...'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' All Done! ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'close': 'click',
        \ })
    
    call visidian#debug#info('START', 'Setup completed')
    call getchar()
    call popup_close(winid)
endfunction

function! visidian#start#first_start() abort
    " Main onboarding function
    call visidian#debug#info('START', 'Beginning first-time setup')
    
    " Welcome screen
    call visidian#start#welcome()
    
    " Check dependencies
    call visidian#start#check_dependencies()
    
    " Setup vault
    call visidian#start#setup_vault()
    " Wait a bit for vault setup to complete
    sleep 500m
    
    " Verify vault path is set before continuing
    if empty(g:visidian_vault_path)
        call visidian#debug#error('START', 'Vault setup was cancelled')
        return
    endif
    
    call visidian#debug#info('START', 'Vault created at: ' . g:visidian_vault_path)
    
    " Setup PARA folders
    sleep 500m
    call visidian#start#setup_para()
    
    " Import existing notes
    sleep 500m
    call visidian#start#import_notes()
    
    " Setup sync
    sleep 500m
    call visidian#start#setup_sync()
    
    " Customize
    sleep 500m
    call visidian#start#customize()
    
    " Finish
    sleep 500m
    call visidian#start#finish()
endfunction
