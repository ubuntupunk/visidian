" Global variables
if !exists('g:visidian_vault_path')
    let g:visidian_vault_path = ''
endif
if !exists('g:visidian_vault_name')
    let g:visidian_vault_name = ''
endif
if !exists('g:visidian_session_dir')
    let g:visidian_session_dir = expand('~/.vim/sessions/visidian/')
endif
if !exists('g:visidian_auto_save_session')
    let g:visidian_auto_save_session = 1
endif
if !exists('g:visidian_config_file')
    let g:visidian_config_file = expand('~/.visidian.json')
endif
if !exists('g:visidian_auto_setup')
    let g:visidian_auto_setup = 1
endif
if !exists('g:visidian_last_note')
    let g:visidian_last_note = ''
endif
if !exists('g:visidian_max_sessions')
    let g:visidian_max_sessions = 5
endif

" FUNCTION: Helper function to manage sessions
function! visidian#ensure_session_dir() abort
    if !isdirectory(g:visidian_session_dir)
        call mkdir(g:visidian_session_dir, 'p')
        call visidian#debug#info('SESSION', 'Created session directory at: ' . g:visidian_session_dir)
    endif
endfunction

" FUNCTION: Get Session File
function! visidian#get_session_file() abort
    let safe_name = substitute(g:visidian_vault_path, '[\/]', '_', 'g')
    return g:visidian_session_dir . safe_name . '.vim'
endfunction

" FUNCTION: Get Session History
function! visidian#get_session_history_file() abort
    let safe_name = substitute(g:visidian_vault_path, '[\/]', '_', 'g')
    return g:visidian_session_dir . safe_name . '.history'
endfunction

" FUNCTION: Rotate Session History
function! s:rotate_session_history(new_session) abort
    let history_file = visidian#get_session_history_file()
    let sessions = []
    
    " Load existing history
    if filereadable(history_file)
        let sessions = readfile(history_file)
    endif
    
    " Add new session to front
    call insert(sessions, a:new_session)
    
    " Keep only the most recent sessions
    let sessions = sessions[0:g:visidian_max_sessions-1]
    
    " Save history
    call writefile(sessions, history_file)
endfunction

" FUNCTION: List Sessions
function! visidian#list_sessions() abort
    let history_file = visidian#get_session_history_file()
    if !filereadable(history_file)
        call visidian#debug#warn('SESSION', 'No session history found.')
        return []
    endif
    
    let sessions = readfile(history_file)
    if empty(sessions)
        call visidian#debug#warn('SESSION', 'No sessions in history.')
        return []
    endif
    
    call visidian#debug#info('SESSION', 'Available sessions (most recent first):')
    let i = 0
    for session in sessions
        let session_data = json_decode(session)
        let timestamp = strftime('%Y-%m-%d %H:%M:%S', session_data.timestamp)
        call visidian#debug#info('SESSION', printf('%d: %s - Last note: %s', 
            \ i, 
            \ timestamp, 
            \ empty(session_data.last_note) ? '[none]' : fnamemodify(session_data.last_note, ':t')))
        let i += 1
    endfor
    
    return sessions
endfunction

" FUNCTION: Choose Session
function! visidian#choose_session() abort
    let sessions = visidian#list_sessions()
    if empty(sessions)
        return 0
    endif
    
    let choice = input('Enter session number (0-' . (len(sessions)-1) . ') or [Enter] to cancel: ')
    if empty(choice)
        call visidian#debug#info('SESSION', "\nCancelled.")
        return 0
    endif
    
    let choice_num = str2nr(choice)
    if choice_num < 0 || choice_num >= len(sessions)
        call visidian#debug#error('SESSION', "\nInvalid session number.")
        return 0
    endif
    
    let session_data = json_decode(sessions[choice_num])
    let g:visidian_last_note = session_data.last_note
    let g:visidian_vault_path = session_data.vault_path
    let g:visidian_vault_name = session_data.vault_name
    
    " Load the chosen session
    call visidian#load_session()
    return 1
endfunction

" FUNCTION: Clear Session
function! visidian#clear_sessions() abort
    let history_file = visidian#get_session_history_file()
    if !filereadable(history_file)
        call visidian#debug#warn('SESSION', 'No session history to clear.')
        return
    endif
    
    let choice = input('Clear all session history? [y/N]: ')
    if choice =~? '^y'
        call delete(history_file)
        call visidian#debug#info('SESSION', "\nSession history cleared.")
    else
        call visidian#debug#info('SESSION', "\nOperation cancelled.")
    endif
endfunction

" FUNCTION: Save session
function! visidian#save_session() abort
    if g:visidian_auto_save_session && !empty(g:visidian_vault_path)
        call visidian#ensure_session_dir()
        let session_file = visidian#get_session_file()
        
        " Save current buffer name if it's a markdown file in the vault
        let current_file = expand('%:p')
        if current_file =~# '^' . escape(g:visidian_vault_path, '/\') . '.*\.md$'
            let g:visidian_last_note = current_file
        endif
        
        " Save session
        execute 'mksession! ' . session_file
        
        " Create session state
        let state = {
            \ 'last_note': g:visidian_last_note,
            \ 'vault_path': g:visidian_vault_path,
            \ 'vault_name': g:visidian_vault_name,
            \ 'timestamp': localtime()
        \ }
        
        " Save state and add to history
        call writefile([json_encode(state)], session_file . '.state')
        call s:rotate_session_history(json_encode(state))
        
        call visidian#debug#info('SESSION', "Session saved to: " . session_file)
        return 1
    endif
    return 0
endfunction

" FUNCTION: Load Session
function! visidian#load_session() abort
    if !empty(g:visidian_vault_path)
        let session_file = visidian#get_session_file()
        let state_file = session_file . '.state'
        
        " Load session state if it exists
        if filereadable(state_file)
            let state_content = join(readfile(state_file), '')
            let state = json_decode(state_content)
            let g:visidian_last_note = get(state, 'last_note', '')
            let g:visidian_vault_path = get(state, 'vault_path', g:visidian_vault_path)
            let g:visidian_vault_name = get(state, 'vault_name', g:visidian_vault_name)
        endif
        
        " Load session if it exists
        if filereadable(session_file)
            " Clear all buffers first
            silent! bufdo bwipeout
            
            " Change to vault directory
            execute 'cd ' . fnameescape(g:visidian_vault_path)
            
            " Load the session
            execute 'source ' . fnameescape(session_file)
            
            " Open NERDTree with vault as root
            call s:open_nerdtree()
            
            " Open last note if it exists
            if !empty(g:visidian_last_note) && filereadable(g:visidian_last_note)
                execute 'edit ' . fnameescape(g:visidian_last_note)
                normal! zz
            endif
            
            call visidian#debug#info('SESSION', "Session loaded from: " . session_file)
            return 1
        else
            call visidian#debug#warn('SESSION', "No existing session found at: " . session_file)
        endif
    endif
    return 0
endfunction

" FUNCTION: Helper function to open NERDTree at vault root
function! s:open_nerdtree() abort
    if exists(':NERDTree')
        " Ensure NERDTree is not already open
        if exists('t:NERDTreeBufName') && bufwinnr(t:NERDTreeBufName) != -1
            NERDTreeClose
        endif
        
        " Escape spaces and special characters in path
        let escaped_path = fnameescape(g:visidian_vault_path)
        
        " Open NERDTree at vault path
        execute 'NERDTree ' . escaped_path
        
        " Focus back on the main window if we have a file open
        if !empty(g:visidian_last_note)
            wincmd p
        endif
    endif
endfunction

" FUNCTION: Main dashboard
function! visidian#dashboard() abort
    " Check if vault path is set
    if !visidian#load_vault_path()
        call visidian#debug#warn('CORE', "No vault configured. Let's set one up!")
        if visidian#create_vault()
            call visidian#debug#info('CORE', "Vault created. Opening dashboard...")
        else
            call visidian#debug#error('CORE', "Failed to create vault. Please try again with :VisidianVault")
            return
        endif
    endif

    " Ensure vault path exists
    if !isdirectory(g:visidian_vault_path)
        call visidian#debug#error('CORE', "Vault directory does not exist: " . g:visidian_vault_path)
        call visidian#debug#warn('CORE', "Please create it or set a new path with :VisidianVault")
        return
    endif

    " Change to vault directory
    execute 'cd ' . fnameescape(g:visidian_vault_path)

    " Try to load existing session first
    if !visidian#load_session()
        " If no session exists, set up a new dashboard
        " Clear all buffers first
        silent! bufdo bwipeout
        
        " Create dashboard buffer
        enew
        setlocal buftype=nofile
        setlocal bufhidden=hide
        setlocal noswapfile
        
        " Set up dashboard layout
        let header = [
            \ '  _   _ _     _     _ _             ',
            \ ' | | | (_)   (_)   | (_)            ',
            \ ' | | | |_ ___ _  __| |_  __ _ _ __  ',
            \ ' | | | | / __| |/ _` | |/ _` | ''_ \ ',
            \ ' \ \_/ / \__ \ | (_| | | (_| | | | |',
            \ '  \___/|_|___/_|\__,_|_|\__,_|_| |_|',
            \ '',
            \ '  Current Vault: ' . g:visidian_vault_path,
            \ '',
            \ '  Available Commands:',
            \ '  :VisidianNote    - Create a new note',
            \ '  :VisidianFolder  - Create a new folder',
            \ '  :VisidianSearch  - Search through notes',
            \ '  :VisidianLink    - Link between notes',
            \ '  :VisidianParaGen - Generate PARA folders',
            \ '  :VisidianHelp    - Show help',
            \ '',
            \ '  Tip: To set up key mappings in your vimrc, use:',
            \ '  let mapleader = "<your-leader-key>"',
            \ '  nnoremap <leader>vf :VisidianNote<CR>',
            \ '  nnoremap <leader>vs :VisidianSearch<CR>',
            \ '  etc.',
            \ '',
            \ '  Pro Tip: Use :call visidian#menu() for a popup menu interface!',
            \ ''
            \ ]
        
        call append(0, header)
        normal! gg
        setlocal nomodifiable
        
        " Open NERDTree with vault as root
        call s:open_nerdtree()
        
        " Save initial session
        call visidian#save_session()
    endif

    " Set up autocommands for session management
    augroup VisidianSession
        autocmd!
        " Save session when leaving Vim
        autocmd VimLeave * call visidian#save_session()
        " Save session when switching buffers
        autocmd BufEnter *.md call visidian#save_session()
    augroup END
endfunction

" FUNCTION: Helper function to ensure path is within home directory
function! s:ensure_home_directory(path) abort
    let home_dir = expand('~')
    let full_path = fnamemodify(a:path, ':p')
    if stridx(full_path, home_dir) == 0
        return full_path
    else
        throw "Vault path must be within the home directory: " . a:path
    endif
endfunction

" FUNCTION: Helper function to read JSON config
function! s:read_json() abort
    if filereadable(g:visidian_config_file)
        try
            let lines = readfile(g:visidian_config_file)
            let data = {}
            for line in lines
                let match = matchlist(line, '\v\s*"([^"]+)":\s*"([^"]+)"')
                if !empty(match)
                    let data[match[1]] = match[2]
                endif
            endfor
            return data
        catch
            return {}
        endtry
    endif
    return {}
endfunction

" FUNCTION: Helper function to write JSON config
function! visidian#write_json(data) abort
    try
        let lines = ['{']
        for key in keys(a:data)
            let escaped_value = substitute(a:data[key], '\(["\\]\)', '\\\1', 'g')
            call add(lines, printf('  "%s": "%s",', key, escaped_value))
        endfor
        if !empty(lines)
            let lines[-1] = substitute(lines[-1], ',$', '', '')
        endif
        call add(lines, '}')
        call writefile(lines, g:visidian_config_file)
        call visidian#debug#info('CONFIG', 'Configuration saved to ' . g:visidian_config_file)
        return 1
    catch
        call visidian#debug#error('CONFIG', "Failed to write configuration to " . g:visidian_config_file . ": " . v:exception)
        return 0
    endtry
endfunction

" FUNCTION: Load the vault path from JSON or prompt for one 
function! visidian#load_vault_path() abort
    if !exists('g:visidian_vault_path') || g:visidian_vault_path == ''
        let json_data = s:read_json()
        if !empty(json_data) && has_key(json_data, 'vault_path')
            try
                let safe_path = s:ensure_home_directory(json_data['vault_path'])
                if !empty(safe_path)
                    let g:visidian_vault_path = safe_path
                    call visidian#debug#info('CORE', 'Loaded vault path from configuration: ' . g:visidian_vault_path)
                    return 1
                endif
            catch
                " Fall through to manual setup
            endtry
        endif
        " If we get here, we need to set up the vault
        return 0
    endif
    return 1
endfunction

" FUNCTION: Create PARA folders
function! visidian#create_para_folders() abort
    " Ensure vault path exists and is normalized
    if empty(g:visidian_vault_path)
        call visidian#debug#error('CORE', "No vault path set. Please create or set a vault first.")
        return 0
    endif

    " Normalize vault path (remove trailing slash)
    let vault_path = substitute(g:visidian_vault_path, '[\/]\+$', '', '')

    let para_folders = ['Projects', 'Areas', 'Resources', 'Archive']
    for folder in para_folders
        " Create folder path without double slashes
        let folder_path = vault_path . '/' . folder
        if !isdirectory(folder_path)
            try
                call mkdir(folder_path, 'p')
                call visidian#debug#info('CORE', "Created folder: " . folder_path)
            catch
                call visidian#debug#error('CORE', "Error creating folder: " . folder_path)
                continue
            endtry
        endif

        " Create README
        let readme_path = folder_path . '/README.md'
        if !filereadable(readme_path)
            try
                let content = [
                    \ '# ' . folder,
                    \ '',
                    \ '## Purpose',
                    \ ''
                \]
                if folder ==# 'Projects'
                    let content += ['For tasks with a defined goal and deadline.']
                elseif folder ==# 'Areas'
                    let content += ['For ongoing responsibilities without a deadline.']
                elseif folder ==# 'Resources'
                    let content += ['For topics of interest or areas of study, not tied to immediate action.']
                elseif folder ==# 'Archive'
                    let content += ['For completed projects, expired areas, or old resources.']
                endif
                call writefile(content, readme_path)
                echo "Created README: " . readme_path
            catch
                echohl ErrorMsg
                echo "Error creating README: " . readme_path
                echo v:exception
                echohl None
                continue
            endtry
        endif

        " Create example note
        let example_path = folder_path . '/example.md'
        if !filereadable(example_path)
            try
                let current_time = strftime('%Y-%m-%d %H:%M:%S')
                let content = []

                " Add YAML frontmatter based on folder type
                if folder ==# 'Projects'
                    let content = [
                        \ '---',
                        \ 'title: Example Project',
                        \ 'date: ' . current_time,
                        \ 'tags: [project, example, task]',
                        \ 'status: active',
                        \ 'deadline: ' . strftime('%Y-%m-%d', localtime() + 86400 * 7),
                        \ 'links: []',
                        \ '---',
                        \ '',
                        \ '# Example Project',
                        \ '',
                        \ '## Overview',
                        \ 'This is an example project note. Projects should have:',
                        \ '',
                        \ '- Clear objectives',
                        \ '- Defined timeline',
                        \ '- Measurable outcomes',
                        \ '',
                        \ '## Tasks',
                        \ '- [ ] First task',
                        \ '- [ ] Second task',
                        \ '- [ ] Third task',
                        \ '',
                        \ '## Resources',
                        \ '- Link to related resources',
                        \ '- Link to reference materials',
                    \]
                elseif folder ==# 'Areas'
                    let content = [
                        \ '---',
                        \ 'title: Example Area',
                        \ 'date: ' . current_time,
                        \ 'tags: [area, example, responsibility]',
                        \ 'status: ongoing',
                        \ 'review_frequency: weekly',
                        \ 'links: []',
                        \ '---',
                        \ '',
                        \ '# Example Area',
                        \ '',
                        \ '## Description',
                        \ 'This is an example area note. Areas represent:',
                        \ '',
                        \ '- Ongoing responsibilities',
                        \ '- Long-term commitments',
                        \ '- Standards to maintain',
                        \ '',
                        \ '## Current Focus',
                        \ '- Key aspect 1',
                        \ '- Key aspect 2',
                        \ '- Key aspect 3',
                    \]
                elseif folder ==# 'Resources'
                    let content = [
                        \ '---',
                        \ 'title: Example Resource',
                        \ 'date: ' . current_time,
                        \ 'tags: [resource, example, reference]',
                        \ 'type: reference',
                        \ 'topics: [example, learning]',
                        \ 'links: []',
                        \ '---',
                        \ '',
                        \ '# Example Resource',
                        \ '',
                        \ '## Summary',
                        \ 'This is an example resource note. Resources are for:',
                        \ '',
                        \ '- Topic research',
                        \ '- Reference materials',
                        \ '- Learning notes',
                        \ '',
                        \ '## Key Points',
                        \ '1. First key point',
                        \ '2. Second key point',
                        \ '3. Third key point',
                    \]
                elseif folder ==# 'Archive'
                    let content = [
                        \ '---',
                        \ 'title: Example Archive',
                        \ 'date: ' . current_time,
                        \ 'tags: [archive, example, completed]',
                        \ 'status: archived',
                        \ 'archive_date: ' . strftime('%Y-%m-%d'),
                        \ 'links: []',
                        \ '---',
                        \ '',
                        \ '# Example Archive',
                        \ '',
                        \ '## Archive Details',
                        \ 'This is an example archive note. Archives contain:',
                        \ '',
                        \ '- Completed projects',
                        \ '- Past areas',
                        \ '- Old resources',
                        \ '',
                        \ '## Archive Context',
                        \ '- Original creation date',
                        \ '- Reason for archiving',
                        \ '- Related active notes',
                    \]
                endif

                call writefile(content, example_path)
                call visidian#debug#info('CORE', "Created example note: " . example_path)
            catch
                call visidian#debug#error('CORE', "Error creating example note: " . example_path)
                continue
            endtry
        endif
    endfor
    return 1
endfunction

" FUNCTION: Set up a new vault
function! visidian#create_vault() abort
    " Get vault name from user
    let vault_name = input("Enter new vault name: ")
    if empty(vault_name)
        call visidian#debug#warn('CORE', "No vault name provided. Vault creation cancelled.")
        return 0
    endif

    " Create full path in home directory
    let vault_path = expand('~/' . vault_name)
    
    try
        " Create vault directory
        if !isdirectory(vault_path)
            call mkdir(vault_path, 'p')
        endif
        
        " Set and save vault path
        let g:visidian_vault_path = vault_path
        
        " Save configuration
        if !visidian#write_json({'vault_path': g:visidian_vault_path})
            throw "Failed to save vault configuration"
        endif
        
        echo "New vault created at " . vault_path

        " Ask about PARA folders
        echo "\nWould you like to set up PARA folders? (y/n): "
        let setup_para = nr2char(getchar())
        echo setup_para
        if setup_para =~? '^y'
            call visidian#create_para_folders()
            call visidian#debug#info('CORE', "PARA folders created with README files")
        endif

        " Change to vault directory
        execute 'cd ' . g:visidian_vault_path
        
        " Create and save initial session
        call visidian#save_session()
        
        " Open NERDTree if available
        if exists(':NERDTree')
            NERDTree
        endif
        
        return 1
    catch
        call visidian#debug#error('CORE', "Failed to create vault: " . v:exception)
        return 0
    endtry
endfunction

" FUNCTION: Create popup menu
function! visidian#menu() abort
 " Clear any existing menu state
    if exists('s:current_line')
        unlet s:current_line
    endif
    if exists('s:current_menu_items')
        unlet s:current_menu_items
    endif
    if exists('s:pending_cmd')
        unlet s:pending_cmd
    endif
 
    " Check if popup feature is available
    if !has('popupwin')
        call visidian#debug#error('UI', "Popup windows not supported in this version of Vim")
        return
    endif

     " Check if we can use Nerd Font icons
    let has_nerdfont = s:has_nerdfont()
    
    " Define icons based on font support
    " let icons = has_nerdfont ? {
    "     \ 'note': "\uf481",      " File icon
    "     \ 'folder': "\uf74a",    " Folder icon
    "     \ 'search': "\uf002",    " Search icon
    "     \ 'link': "\uf0c1",      " Link icon
    "     \ 'para': "\uf45c",      " Organization icon
    "     \ 'save': "\uf0c7",      " Save icon
    "     \ 'load': "\uf019",      " Load icon
    "     \ 'list': "\uf03a",      " List icon
    "     \ 'choose': "\uf0a4",    " Pointer icon
    "     \ 'clear': "\uf2ed",     " Trash icon
    "     \ 'setup': "\u2699",     " Gear icon
    "     \ 'sync': "\uf021",      " Sync icon
    "     \ 'preview': "\uf06e",   " Eye icon
    "     \ 'sidebar': "\uf0db",   " Layout icon
    "     \ 'help': "\uf059",      " Question mark icon
    "     \ 'bookmark': "\uf02e",  " Bookmark icon
    "     \ 'close': "\uf00d"      " X icon
    "     \ } : {
    let icons = {
            \ 'note': '[+]',
            \ 'folder': '[D]',
            \ 'search': '[S]',
            \ 'link': '[L]',
            \ 'para': '[P]',
            \ 'save': '[W]',
            \ 'load': '[R]',
            \ 'list': '[LS]',
            \ 'choose': '[C]',
            \ 'clear': '[X]',
            \ 'setup': '[S]',
            \ 'sync': '[Y]',
            \ 'preview': '[V]',
            \ 'sidebar': '[B]',
            \ 'help': '[?]',
            \ 'bookmark': '[M]',
            \ 'close': '[Q]'
        \ }

 " Log the icons dictionary
    call visidian#debug#info('DEBUG', "Icons dictionary: " . string(icons))
  
    " Define menu items with descriptions and commands
    let menu_items = [
        \ {'id': 1,  'text': icons.note . ' New Note',          'cmd': 'call visidian#new_md_file()',   'desc': 'Create a new markdown note'},
        \ {'id': 2,  'text': icons.folder . ' New Folder',      'cmd': 'call visidian#new_folder()',    'desc': 'Create a new folder'},
        \ {'id': 3,  'text': icons.search . ' Search Notes',    'cmd': 'call visidian#search()',     'desc': 'Search through your notes'},
        \ {'id': 4,  'text': icons.link . ' Link Notes',        'cmd': 'call visidian#link_notes()',     'desc': 'Create links between notes'},
        \ {'id': 5,  'text': icons.para . ' PARA Folders',      'cmd': 'call visidian#create_para_folders()',   'desc': 'Generate PARA folder structure'},
        \ {'id': 6,  'text': icons.save . ' Save Session',      'cmd': 'call visidian#save_session()',  'desc': 'Save current session'},
        \ {'id': 7,  'text': icons.load . ' Load Session',      'cmd': 'call visidian#load_session()',  'desc': 'Load saved session'},
        \ {'id': 8,  'text': icons.list . ' List Sessions',     'cmd': 'call visidian#list_sessions()', 'desc': 'View available sessions'},
        \ {'id': 9,  'text': icons.choose . ' Choose Session',  'cmd': 'call visidian#choose_session()', 'desc': 'Select a previous session'},
        \ {'id': 10, 'text': icons.clear . ' Clear Sessions',   'cmd': 'call visidian#clear_sessions()', 'desc': 'Clear session history'},
        \ {'id': 11, 'text': icons.setup . ' Setup Sync',       'cmd': 'call visidian#sync()', 'desc': 'Setup sync method'},
        \ {'id': 12, 'text': icons.sync . ' Toggle AutoSync',   'cmd': 'call visidian#toggle_auto_sync()', 'desc': 'Toggle auto-sync feature'},
        \ {'id': 13, 'text': icons.preview . ' Toggle Preview', 'cmd': 'call visidian#toggle_preview()', 'desc': 'Toggle markdown preview'},
        \ {'id': 14, 'text': icons.sidebar . ' Toggle Sidebar', 'cmd': 'call visidian#toggle_sidebar()', 'desc': 'Toggle sidebar visibility'},
        \ {'id': 15, 'text': icons.help . ' Help',              'cmd': 'call visidian#help()',         'desc': 'Show help'},
        \ {'id': 16, 'text': icons.para . ' Import & Sort',     'cmd': 'call visidian#import_sort()', 'desc': 'Import and sort files using PARA'},
        \ {'id': 17, 'text': icons.bookmark . ' Bookmarks',     'cmd': 'call visidian#bookmarking#menu()', 'desc': 'Bookmarks'},
        \ {'id': 18, 'text': icons.close . ' Close Menu',       'cmd': 'close',                'desc': 'Close this menu'}
     \]
" Log the menu items
    call visidian#debug#info('DEBUG', "Menu items: " . string(menu_items))

    " Calculate menu dimensions
    let max_text_len = max(map(copy(menu_items), 'strwidth(v:val.text)'))
    let max_desc_len = max(map(copy(menu_items), 'strwidth(v:val.desc)'))
    let menu_width = max_text_len + max_desc_len + 6
    let menu_height = len(menu_items) + 2

    " Calculate position (center of screen)
    let pos_x = ((&columns - menu_width) / 2)
    let pos_y = ((&lines - menu_height) / 2)

    " Create the menu content
    let menu_content = []
    let i = 1
    for item in menu_items
        let padding = repeat(' ', max_text_len - strwidth(item.text) + 2)
        let num_prefix = printf('%2d. ', i)
        call add(menu_content, printf('%s%s%s%s', num_prefix, item.text, padding, item.desc))
        let i += 1
    endfor

    " Create the popup window
    let popup_winid = popup_create(menu_content, {
        \ 'title': ' Visidian Menu ',
        \ 'pos': 'center',
        \ 'line': pos_y,
        \ 'col': pos_x,
        \ 'minwidth': menu_width,
        \ 'minheight': menu_height,
        \ 'border': [1,1,1,1],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'padding': [0,1,0,1],
        \ 'mapping': 1,
        \ 'cursorline': 1,
        \ 'filter': function('s:menu_filter'),
        \ 'callback': function('s:menu_callback')
        \ })
    
    call visidian#debug#info('UI', "Popup window created with ID: " . popup_winid)

    " Store menu items for the filter function
    let s:current_menu_items = menu_items
    let s:current_popup_id = popup_winid

    " Add highlighting
    if has_nerdfont
        call win_execute(popup_winid, 'syntax match VisidianMenuIcon /[' . join(values(icons), '') . ']/')
    else
        call win_execute(popup_winid, 'syntax match VisidianMenuIcon /\[\w\+\]/')
    endif
    call win_execute(popup_winid, 'syntax match VisidianMenuNumber /^\d\+\. /')
    call win_execute(popup_winid, 'syntax match VisidianMenuText /\S\+\s\+\zs.*$/')
    call win_execute(popup_winid, 'highlight VisidianMenuIcon ctermfg=214 guifg=#fabd2f')
    call win_execute(popup_winid, 'highlight VisidianMenuNumber ctermfg=109 guifg=#83a598')
    call win_execute(popup_winid, 'highlight VisidianMenuText ctermfg=223 guifg=#ebdbb2')
    call win_execute(popup_winid, 'highlight PopupSelected ctermfg=208 guifg=#fe8019 gui=bold')
endfunction

" Execute menu command safely
function! s:execute_menu_command(cmd) abort
    " Store command in a script variable to prevent interference
    let s:pending_cmd = a:cmd
    
    " Clear any existing state
    if exists('s:current_line')
        unlet s:current_line
    endif
    if exists('s:current_menu_items')
        unlet s:current_menu_items
    endif
    
    " Execute the command after a brief delay to ensure cleanup
    call timer_start(50, {-> s:do_execute_command()})
endfunction

function! s:do_execute_command() abort
    if exists('s:pending_cmd')
        execute s:pending_cmd
        unlet s:pending_cmd
    endif
endfunction

" FUNCTION: Menu filter
function! s:menu_filter(winid, key) abort
    " Get current line number
    "let pos = popup_getpos(a:winid)
    "let current_line = pos.lnum

    " Initialize current line if not already set
    if !exists('s:current_line') 
        let s:current_line = 1
    endif

    let max_line = len(s:current_menu_items)
    call visidian#debug#trace('UI', 'Menu max line: ' . max_line)

    " Handle key input
    if a:key == 'j' || a:key == "\<Down>"
        let s:current_line = min([s:current_line + 1, max_line])
        call visidian#debug#trace('UI', 'Menu current line: ' . s:current_line)
        call popup_filter_menu(a:winid, "\<Down>")
        return 1
    elseif a:key == 'k' || a:key == "\<Up>"
        let s:current_line = max([s:current_line - 1, 1])
        call visidian#debug#trace('UI', 'Menu current line: ' . s:current_line)
        call popup_filter_menu(a:winid, "\<Up>")
        return 1
    elseif a:key == "\<CR>" || a:key == ' '
        " Execute the command for the current line
        let item = s:current_menu_items[s:current_line - 1]
        call visidian#debug#debug('UI', 'Executing menu command: ' . item.cmd)
        if item.cmd == 'close'
            call popup_close(a:winid)
        else
            call popup_close(a:winid)
            " Execute command after closing popup to avoid interference
            "call timer_start(10, {-> execute(item.cmd)})
            call s:execute_menu_command(item.cmd)
        endif
        return 1
    elseif a:key == 'q' || a:key == "\<Esc>"
        call popup_close(a:winid)
        return 1
    endif

    " Handle number keys for quick selection
    let num = str2nr(a:key)
    if num > 0 && num <= max_line
        let s:current_line = num
        let item = s:current_menu_items[num - 1]
        call visidian#debug#debug('UI', 'Quick menu selection: ' .num . " " . item.cmd)
        call popup_close(a:winid)
        if item.cmd != 'close'
            " Execute command after closing popup to avoid interference
            "call timer_start(10, {-> execute(item.cmd)})
            call s:execute_menu_command(item.cmd)
        endif
        return 1
    endif

    return popup_filter_menu(a:winid, a:key)
endfunction

" FUNCTION: Menu callback
function! s:menu_callback(winid, result) abort
" Execute the command associated with the selected menu item
    if a:result > 0 && a:result <= len(s:current_menu_items)
        let selected_item = s:current_menu_items[a:result - 1]
        execute selected_item.cmd
    endif
    " Clean up menu items
    if exists('s:current_menu_items')
        unlet s:current_menu_items
    endif
    if exists('s:current_popup_id')
        unlet s:current_popup_id
    endif
endfunction

" FUNCTION: Highlight Todo
 function! HighlightTodo()
 execute(":highlight TODO ctermbg=grey ctermfg=white")
 endfunction
map <F7> :call HighlightTodo()<CR>

" FUNCTION SIGN-TODO
 function! SignTodo()  
 execute(":sign define todo text=!! texthl=Todo")
 execute(":sign place ".line(".")." line=".line(".")." name=todo file=".expand("%:p"))
 endfunction
 map <F3> :call SignTodo()<CR>

" FUNCTION SIGN-ALL-TODO-LINES
function! SignLines() range
  let n = a:firstline
  execute(":sign define todo text=!! texthl=Todo")
  while n <= a:lastline
    if getline(n) =~ '\(TODO\FIXME\|XXX\)'
      execute(":sign place ".n." line=".n." name=todo file=".expand("%:p"))
    endif
    let n = n + 1
  endwhile  
endfunction
map <F4> :call SignLines()<CR>

" FUNCTION VisidianToggleSidebar
function! visidian#toggle_sidebar()
  if exists('g:visidian_sidebar_open') && g:visidian_sidebar_open
    let g:visidian_sidebar_open = 0
    " Close the sidebar
    if exists(':NERDTreeToggle')
      NERDTreeToggle
    else
      " Assuming netrw is in the rightmost window
      exe "wincmd L"
      if &filetype == 'netrw'
        close
      endif
    endif
  else
    let g:visidian_sidebar_open = 1
    " Open the sidebar
    if exists(':NERDTreeToggle')
      NERDTreeToggle
    else
      " Open netrw if NERDTree isn't available
      Vexplore
    endif
  endif
endfunction

" FUNCTION: Check if Nerd Fonts are available
function! s:has_nerdfont() abort
    " Try to display a nerd font character and check if its width is correct
    let test_char = ''
    return strwidth(test_char) == 1
endfunction

" map key to call dashboard
nnoremap <silent> <leader>1 :call visidian#dashboard()<CR>

" If you want to open only the menu without the full dashboard:
nnoremap <silent> <leader>2 :call visidian#menu()<CR>

" FUNCTION: PARA statusline function
function! visidian#para_status() abort
    let l:path = expand('%:p')
    if empty(l:path) || empty(g:visidian_vault_path)
        return ''
    endif

    " Normalize paths
    let l:path = substitute(l:path, '\\', '/', 'g')
    let l:vault = substitute(g:visidian_vault_path, '\\', '/', 'g')
    let l:vault = substitute(l:vault, '/$', '', '')

    " Check if file is in vault
    if l:path !~# '^' . escape(l:vault, '/') . '/'
        return ''
    endif

    " Debug path matching
    if g:visidian_debug
        call visidian#debug#trace('UI', 'Path: ' . l:path)
    endif

    " Determine PARA context with colors
    if l:path =~? '/Projects/'
        return '[P]rojects '
    elseif l:path =~? '/Areas/'
        return '[A]reas '
    elseif l:path =~? '/Resources/'
        return '[R]esources '
    elseif l:path =~? '/Archive\|Archives/'
        return '[AR]chives '
    endif

    return ''
endfunction

" FUNCTION: clear cache of non-existent files
function! visidian#clear_cache()
    if !exists('g:visidian_cache')
        let g:visidian_cache = {}
        call visidian#debug#info('CACHE', 'Initialized empty cache')
        return
    endif
    
    call visidian#debug#debug('CACHE', 'Starting cache clear with keys: ' . string(keys(g:visidian_cache)))
    let new_cache = {}
    for path in keys(g:visidian_cache)
        if empty(g:visidian_vault_path)
            call visidian#debug#error('CACHE', 'Vault path not set or invalid')
            return
        endif

        let full_path = g:visidian_vault_path . file
        call visidian#debug#trace('CACHE', 'Checking file: ' . full_path)
        if !filereadable(full_path)
            let new_cache[path] = g:visidian_cache[path]
        else
            call visidian#debug#debug('CACHE', 'Removing non-existent file from cache: ' . path)
        endif
    endfor
    let g:visidian_cache = new_cache
    call visidian#debug#info('CACHE', 'Cache cleared, remaining keys: ' . string(keys(g:visidian_cache)))
endfunction

" FUNCTION: Helper to cache file information
function! s:cache_file_info(file)
    " Ensure the file path is relative to the vault
    let file_path = substitute(a:file, '^' . g:visidian_vault_path, '', '')
    let full_path = g:visidian_vault_path . a:file
    call visidian#debug#debug('CACHE', 'Caching file: ' . full_path)
    
    try
        let lines = readfile(full_path)
        let yaml_start = match(lines, '^---$')
        let yaml_end = match(lines, '^---$', yaml_start + 1)
        if yaml_start != -1 && yaml_end != -1
            let g:visidian_cache[a:file] = {
                \ 'yaml': lines[yaml_start+1 : yaml_end-1]
                \ }
            call visidian#debug#debug('CACHE', 'Added YAML to cache: ' . a:file)
        else
            let g:visidian_cache[a:file] = {'yaml': []}
            call visidian#debug#debug('CACHE', 'Added empty YAML to cache: ' . a:file)
        endif
    catch /^Vim\%((\a\+)\)\=:E484/
        call visidian#debug#warn('CACHE', 'File not found, removing from cache: ' . a:file)
        " Remove from cache if file no longer exists
        call remove(g:visidian_cache, a:file)
    endtry
endfunction

" FUNCTION: Call Search
function! visidian#search()
    call visidian#search#search()
endfunction

" FUNCTION: Create a new vault
function! visidian#create_vault()
    try
        let vault_name = input("Enter new vault name: ")
        if vault_name != ''
            let vault_path = expand('~/') . vault_name . '/'
            call mkdir(vault_path, 'p')
            let g:visidian_vault_path = vault_path
            echo "New vault created at " . vault_path
            " Save to JSON for future use
            if !visidian#write_json({'vault_path': g:visidian_vault_path})
                throw "Failed to save vault configuration"
            endif
        else
            call visidian#debug#warn('CORE', "No vault name provided.")
        endif
    catch /^Vim\%((\a\+)\)\=:E739/
        call visidian#debug#error('CORE', "Cannot create directory: Permission denied.")
    endtry
endfunction

" FUNCTION: Call Create a new markdown file (with YAML front matter)
function! visidian#new_md_file() abort
    " Check if vault exists
    if empty(g:visidian_vault_path)
        call visidian#debug#error('CORE', "No vault path set. Please create or load a vault first.")
        return 0
    endif

    " Normalize vault path
    let vault_path = substitute(g:visidian_vault_path, '[\/]\+$', '', '')

    " Define PARA folders (case-sensitive)
    let para_folders = ['Projects', 'Areas', 'Resources', 'Archive']

    " Get filename
    let filename = input('Enter filename (without .md): ')
    if empty(filename)
        call visidian#debug#warn('CORE', "\nCancelled.")
        return 0
    endif

    " Add .md extension if not present
    if filename !~? '\.md$'
        let filename = filename . '.md'
    endif

    " Get folder category
    let category_msg = "Choose category:\n"
    let i = 1
    for folder in para_folders
        let category_msg .= printf("%d) %s\n", i, folder)
        let i += 1
    endfor
    let category_choice = input(category_msg . 'Enter number (1-' . len(para_folders) . '): ')
    
    if empty(category_choice) || category_choice < 1 || category_choice > len(para_folders)
        call visidian#debug#warn('CORE', "\nInvalid category. Cancelled.")
        return 0
    endif

    let category = para_folders[category_choice - 1]

    " Get subcategory if needed
    let subcategory = input('Enter subcategory (optional, press Enter to skip): ')

    " Construct the full path
    let file_path = vault_path . '/' . category
    if !empty(subcategory)
        " Convert subcategory to title case to match PARA style
        let subcategory_parts = split(subcategory, '\s\+\|[_-]\+')
        let subcategory_titled = map(subcategory_parts, 'toupper(v:val[0]) . tolower(v:val[1:])')
        let subcategory = join(subcategory_titled, '')
        
        " Check if a similar directory exists (case-insensitive)
        let found_existing = 0
        if isdirectory(file_path)
            for existing_dir in glob(file_path . '/*', 0, 1)
                if isdirectory(existing_dir) && tolower(fnamemodify(existing_dir, ':t')) ==# tolower(subcategory)
                    let subcategory = fnamemodify(existing_dir, ':t')
                    let found_existing = 1
                    break
                endif
            endfor
        endif

        let file_path .= '/' . subcategory
    endif

    " Create directory if it doesn't exist
    if !isdirectory(file_path)
        try
            call mkdir(file_path, 'p')
        catch
            call visidian#debug#error('CORE', "Error creating directory: " . file_path)
            return 0
        endtry
    endif

    " Add filename to path
    let file_path .= '/' . filename

    " Check if file already exists
    if filereadable(file_path)
        call visidian#debug#warn('CORE', "\nFile already exists: " . file_path)
        let choice = input('Overwrite? [y/N]: ')
        if choice !~? '^y'
            call visidian#debug#warn('CORE', "\nCancelled.")
            return 0
        endif
    endif

    " Create the file with YAML frontmatter
    try
        let current_time = strftime('%Y-%m-%d %H:%M:%S')
        let content = [
            \ '---',
            \ 'title: ' . fnamemodify(filename, ':r'),
            \ 'date: ' . current_time,
            \ 'category: ' . category,
            \ ]

        if !empty(subcategory)
            let content += ['subcategory: ' . subcategory]
        endif

        let content += [
            \ 'tags: []',
            \ 'status: active',
            \ 'links: []',
            \ '---',
            \ '',
            \ '# ' . fnamemodify(filename, ':r'),
            \ '',
            \ '## Overview',
            \ '',
            \ ]

        call writefile(content, file_path)
        execute 'edit ' . fnameescape(file_path)
        call visidian#debug#info('CORE', "Created file: " . file_path)
        return 1
    catch
        call visidian#debug#error('CORE', "Error creating file: " . file_path)
        return 0
    endtry
endfunction

" FUNCTION: Call Markdown Preview
function! visidian#toggle_preview()
    call visidian#preview#toggle_preview()
endfunction

" FUNCTION: Create a new folder
function! visidian#new_folder() abort
    " Check if vault exists
    if empty(g:visidian_vault_path)
        call visidian#debug#error('CORE', "No vault path set. Please create or load a vault first.")
        return 0
    endif

    " Normalize vault path
    let vault_path = substitute(g:visidian_vault_path, '[\/]\+$', '', '')

    " Define PARA folders (case-sensitive)
    let para_folders = ['Projects', 'Areas', 'Resources', 'Archive']

    " Get folder category
    let category_msg = "Choose category:\n"
    let i = 1
    for folder in para_folders
        let category_msg .= printf("%d) %s\n", i, folder)
        let i += 1
    endfor
    let category_choice = input(category_msg . 'Enter number (1-' . len(para_folders) . '): ')
    
    if empty(category_choice)
        call visidian#debug#warn('CORE', "\nCancelled.")
        return 0
    endif

    let choice_num = str2nr(category_choice)
    if choice_num < 1 || choice_num > len(para_folders)
        call visidian#debug#warn('CORE', "\nInvalid category. Cancelled.")
        return 0
    endif

    let category = para_folders[choice_num - 1]

    " Get folder name
    let folder_name = input('Enter folder name: ')
    if empty(folder_name)
        call visidian#debug#warn('CORE', "\nCancelled.")
        return 0
    endif

    " Convert folder name to title case
    let folder_parts = split(folder_name, '\s\+\|[_-]\+')
    let folder_titled = map(folder_parts, 'toupper(v:val[0]) . tolower(v:val[1:])')
    let folder_name = join(folder_titled, '')

    " Construct the full path
    let folder_path = vault_path . '/' . category . '/' . folder_name

    " Check if folder already exists
    if isdirectory(folder_path)
        call visidian#debug#warn('CORE', "\nFolder already exists: " . folder_path)
        return 0
    endif

    " Create the folder
    try
        call mkdir(folder_path, 'p')
        call visidian#debug#info('CORE', "\nCreated folder: " . folder_path)

        " Create example note in the new folder
        let example_path = folder_path . '/README.md'
        let current_time = strftime('%Y-%m-%d %H:%M:%S')
        let content = [
            \ '---',
            \ 'title: ' . folder_name . ' Overview',
            \ 'date: ' . current_time,
            \ 'category: ' . category,
            \ 'subcategory: ' . folder_name,
            \ 'tags: []',
            \ 'status: active',
            \ 'links: []',
            \ '---',
            \ '',
            \ '# ' . folder_name . ' Overview',
            \ '',
            \ '## Purpose',
            \ '',
            \ 'Describe the purpose of this folder here.',
            \ '',
            \ '## Contents',
            \ '',
            \ '- List important files and subfolders',
            \ '- Add brief descriptions',
            \ '',
            \ ]

        call writefile(content, example_path)
        call visidian#debug#info('CORE', "Created README.md in new folder")
        
        " Open the new README in the current window
        execute 'edit ' . fnameescape(example_path)
        
        return 1
    catch
        call visidian#debug#error('CORE', "\nError creating folder: " . folder_path)
        return 0
    endtry
endfunction

" FUNCTION: Call Link notes
function! visidian#link_notes()
    call visidian#link_notes#link_notes()
endfunction

"FUNCTION: Call Sort notes
function! visidian#sort()
  call visidian#sort#sort()
endfunction  

" FUNCTION: Generate PKM folders using the PARA method
function! visidian#para()
    if g:visidian_vault_path == ''
        call visidian#debug#error('CORE', "No vault path set. Please create or set a vault first.")
        return
    endif

    let para_folders = ['projects', 'areas', 'resources', 'archives']
    for folder in para_folders
        try
            call mkdir(g:visidian_vault_path . folder, 'p')
            call visidian#debug#info('CORE', "Created folder: " . folder)
        catch /^Vim\%((\a\+)\)\=:E739/
            call visidian#debug#error('CORE', "Error creating folder " . folder . ": Permission denied.")
        endtry
    endfor
endfunction

" FUNCTION: Toggle Spelling, Thesaurus
function! visidian#toggle_spell()
  " File types where spell checking might be relevant
  if &filetype =~ '\v^(markdown|tex|text)$'
    if &spell
      setlocal nospell
      setlocal thesaurus=
      call visidian#debug#info('SPELL', "Spell checking and Thesaurus disabled")
    else
      setlocal spell
      " Ensure spellfile is set
      if empty(&spellfile)
        setlocal spellfile=~/.vim/spell/en.utf-8.add
      endif
      " Try to find the thesaurus file in different locations
      let thesaurus_path = ""
      for dir in ['~/.vim/plugin/','~/.vim/spell', '~/.vim/', '~/.config/nvim/', '~/.vim_runtime/sources_non_forked/visidian.vim']
        if filereadable(expand(dir . 'thesaurus.txt'))
          let thesaurus_path = expand(dir . 'thesaurus.txt')
          break
        endif
      endfor
      if !empty(thesaurus_path)
        setlocal thesaurus+=thesaurus_path
      else
        call visidian#debug#warn('SPELL', "Thesaurus file not found in specified locations.")
      endif
      call visidian#debug#info('SPELL', "Spell checking and Thesaurus enabled")
    endif
  else
    call visidian#debug#warn('SPELL', "Spell checking and Thesaurus not applicable for this file type")
  endif
endfunction

" Enable spell checking by default for relevant file types
autocmd FileType markdown,tex,text setlocal spell

" Example mapping to toggle spell-checking and thesaurus
" nnoremap <silent> <leader>s :call visidian#toggle_spell()<CR>

" Removed VisidianGenerateTags() as it's now in autoload/visidian/tags.vim

" FUNCTION: Help
function! visidian#help()
    let paths = [
        \ '~/.vim/visidian.vim/doc/visidian_help.txt',
        \ '~/.vim/plugins/visidian.vim/doc/visidian_help.txt',
        \ '$VIMRUNTIME/visidian.vim/doc/visidian_help.txt',
        \ '$HOME/.vim/plugged/visidian.vim/doc/visidian_help.txt',
        \ '$HOME/.vim/bundle/visidian.vim/doc/visidian_help.txt',
        \ '$HOME/.vim_runtime/sources_non_forked/visidian.vim/doc/visidian_help.txt'
    \ ]

    for path in paths
        let full_path = expand(path)
        if filereadable(full_path)
            execute 'split ' . full_path
            return
        endif
    endfor

    call visidian#debug#error('CORE', "Help file for Visidian not found in any expected locations.")
endfunction

" FUNCTION: Call Sync
function! visidian#sync()
    call visidian#sync#sync()
endfunction

" Moved function for autosync into sync.vim

" Auto-save session on exit
augroup VisidianSession
    autocmd!
    autocmd VimLeave * call visidian#save_session()
augroup END

" FUNCTION: Import and sort files from a directory
function! visidian#import_sort() abort
    " Check if vault path is set
    if empty(g:visidian_vault_path)
        echohl ErrorMsg
        echo "No vault path set. Please create or set a vault first."
        echohl None
        return
    endif

    " Ask for import directory
    let import_dir = input('Enter path to import from (or press Enter for default import/ folder): ')
    
    " If no directory specified, use default import directory
    if empty(import_dir)
        let import_dir = g:visidian_vault_path . 'import'
        " Create import directory if it doesn't exist
        if !isdirectory(import_dir)
            call mkdir(import_dir, 'p')
            echo "Created default import directory at: " . import_dir
        endif
    endif

    " Normalize path
    let import_dir = fnamemodify(import_dir, ':p')
    
    " Check if directory exists
    if !isdirectory(import_dir)
        echohl ErrorMsg
        echo "Directory does not exist: " . import_dir
        echohl None
        return
    endif

    " Set import directory as vault path temporarily
    let original_vault_path = g:visidian_vault_path
    let g:visidian_vault_path = import_dir

    " Run the sort
    echo "Sorting files from: " . import_dir
    call visidian#sort#sort()

    " Restore original vault path
    let g:visidian_vault_path = original_vault_path
endfunction

" FUNCTION: Session menu
function! visidian#menu_session() abort
    " Create menu options
    let options = [
        \ '1. Save current session',
        \ '2. Load last session',
        \ '3. List available sessions',
        \ '4. Choose and load session',
        \ '5. Clear session history',
        \ 'q. Cancel'
    \ ]
    
    " Display menu
    echo "Session Management\n"
    echo "==================\n"
    for option in options
        echo option
    endfor
    
    " Get user choice
    let choice = input("\nEnter your choice (1-5 or q): ")
    echo "\n"
    
    if choice == '1'
        call visidian#save_session()
        echo "Session saved."
    elseif choice == '2'
        if visidian#load_session()
            echo "Session loaded."
        else
            echo "No session found to load."
        endif
    elseif choice == '3'
        call visidian#list_sessions()
    elseif choice == '4'
        if visidian#choose_session()
            echo "Session loaded."
        endif
    elseif choice == '5'
        let confirm = input("Are you sure you want to clear all session history? (y/N): ")
        if confirm =~? '^y'
            call visidian#clear_sessions()
        else
            echo "Operation cancelled."
        endif
    else
        echo "Operation cancelled."
    endif
endfunction

function! visidian#init() abort
    call visidian#debug#debug('CORE', 'Initializing Visidian')
    
    " Check if we should auto setup
    if g:visidian_auto_setup && !filereadable(g:visidian_config_file)
        call visidian#debug#info('CORE', 'First start detected, running auto setup')
        call visidian#setup#start()
        
        " Disable auto setup after first run
        let g:visidian_auto_setup = 0
        call s:save_config()
        return
    endif
endfunction
