" Visidian First Start
" Maintainer: ubuntupunk
" License: GPL3

function! visidian#start#welcome() abort
    " Force immediate redraw
    redraw!
    
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

" Track the current step in the setup process
let s:setup_step = 0

function! s:continue_setup() abort
    let s:setup_step += 1
    if s:setup_step == 1
        call visidian#start#setup_para()
    elseif s:setup_step == 2
        call visidian#start#import_notes()
    elseif s:setup_step == 3
        call visidian#start#setup_sync()
    elseif s:setup_step == 4
        call visidian#start#customize()
    elseif s:setup_step == 5
        call visidian#start#finish()
    endif
endfunction

function! visidian#start#first_start() abort
    " Reset setup step
    let s:setup_step = 0
    
    " Force immediate screen refresh
    redraw!
    
    " Main onboarding function
    call visidian#debug#info('START', 'Beginning first-time setup')
    
    " Welcome screen
    call visidian#start#welcome()
    
    " Check dependencies
    call visidian#start#check_dependencies()
    
    " Setup vault
    call visidian#start#setup_vault()
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
        \ '  [e] to select an Existing folder',
        \ '  [q] to Quit setup'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' Vault Setup ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:vault_filter'),
        \ 'callback': function('s:vault_callback'),
        \ 'focusable': 1,
        \ })
    
    " Focus the popup immediately
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    
    call visidian#debug#info('START', 'Displayed vault setup options')
endfunction

function! s:select_vault_path() abort
    " Try using browse() first
    if has('browse')
        let path = browse(0, 'Select Vault Directory', expand('~'), '')
    else
        " Fallback to input() in console mode
        echo "\nEnter vault path (or press Enter to cancel):"
        let path = input('Path: ', expand('~'), 'dir')
        echo "\n"  " Add newline after input
    endif
    return path
endfunction

function! s:vault_filter(winid, key) abort
    if a:key ==# 'n'
        call popup_close(a:winid)
        call visidian#create_vault()
        return 1
    elseif a:key ==# 'e'
        call popup_close(a:winid)
        let path = s:select_vault_path()
        if !empty(path)
            " Expand path to handle ~ and environment variables
            let path = expand(path)
            " Ensure directory exists
            if !isdirectory(path)
                echo "\nDirectory does not exist. Create it? (y/n)"
                let choice = nr2char(getchar())
                echo "\n"
                if choice ==? 'y'
                    call mkdir(path, 'p')
                else
                    call visidian#start#setup_vault()
                    return 1
                endif
            endif
            let g:visidian_vault_path = path
            call visidian#debug#info('START', 'Selected vault path: ' . path)
            return 1
        endif
        " If selection was cancelled, show vault setup again
        call visidian#start#setup_vault()
    elseif a:key ==# 'q'
        call popup_close(a:winid)
        return 1
    endif
    return 0
endfunction

function! s:vault_callback(id, result) abort
    if !empty(g:visidian_vault_path)
        call visidian#debug#info('START', 'Vault setup completed successfully')
        " Continue with next step
        call timer_start(500, {-> s:continue_setup()})
    else
        call visidian#debug#error('START', 'Vault setup did not complete successfully')
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
        \ 'callback': {id, result -> timer_start(500, {-> s:continue_setup()})},
        \ 'focusable': 1,
        \ })
    
    " Focus the popup immediately
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    
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
        \ 'callback': {id, result -> timer_start(500, {-> s:continue_setup()})},
        \ 'focusable': 1,
        \ })
    
    " Focus the popup immediately
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    
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
        \ 'callback': {id, result -> timer_start(500, {-> s:continue_setup()})},
        \ 'focusable': 1,
        \ })
    
    " Focus the popup immediately
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    
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
        \ 'Would you like to view and customize settings?',
        \ '',
        \ 'A new buffer will open with all available settings.',
        \ 'You can copy the ones you want to your vimrc.',
        \ '',
        \ 'Press:',
        \ '  [y] to view settings (press any key to continue after viewing)',
        \ '  [n] to finish setup'
        \ ]
    
    let winid = popup_create(msg, {
        \ 'title': ' Settings ',
        \ 'padding': [1,2,1,2],
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'pos': 'center',
        \ 'filter': function('s:customize_filter'),
        \ 'callback': {id, result -> timer_start(500, {-> s:continue_setup()})},
        \ 'focusable': 1,
        \ })
    
    " Focus the popup immediately
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    
    call visidian#debug#info('START', 'Displayed customization options')
endfunction

function! s:customize_filter(winid, key) abort
    if a:key ==# 'y'
        call popup_close(a:winid)
        " Open settings in a new buffer
        new
        setlocal buftype=nofile
        setlocal bufhidden=wipe
        setlocal noswapfile
        setlocal filetype=markdown
        
        " Add settings content
        call append(0, [
            \ '# Visidian Settings',
            \ '',
            \ '## Key Mappings',
            \ '```vim',
            \ '" Default prefix for all mappings',
            \ 'let g:visidian_map_prefix = "\v"',
            \ '```',
            \ '',
            \ '## Preview Options',
            \ '```vim',
            \ '" Enable/disable preview (1/0)',
            \ 'let g:visidian_preview_enabled = 1',
            \ '```',
            \ '',
            \ '## Auto-sync Settings',
            \ '```vim',
            \ '" Enable/disable auto-sync (1/0)',
            \ 'let g:visidian_autosync = 1',
            \ '```',
            \ '',
            \ '## Status Line',
            \ '```vim',
            \ '" Enable/disable status line integration (1/0)',
            \ 'let g:visidian_statusline = 1',
            \ '```',
            \ '',
            \ '# Instructions',
            \ '1. Review the settings above',
            \ '2. Copy desired settings to your vimrc',
            \ '3. Close this buffer when done (use :q)',
            \ '',
            \ 'Press any key to continue setup...'
            \ ])
        
        " Move cursor to top
        normal! gg
        
        " Wait for user to read and close the buffer
        while bufexists('%')
            redraw
            let char = getchar()
            if char != 0
                bwipeout
                break
            endif
            sleep 100m
        endwhile
        
        return 1
    elseif a:key ==# 'n'
        call popup_close(a:winid)
        return 1
    endif
    return 0
endfunction

function! visidian#start#finish() abort
    let msg = [
        \ 'Setup Complete!',
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
        \ 'filter': function('s:finish_filter'),
        \ 'focusable': 1,
        \ })
    
    " Focus the popup immediately
    call win_execute(winid, 'redraw')
    call popup_setoptions(winid, {'focused': 1})
    
    call visidian#debug#info('START', 'Setup completed')
endfunction

function! s:finish_filter(winid, key) abort
    call popup_close(a:winid)
    return 1
endfunction
