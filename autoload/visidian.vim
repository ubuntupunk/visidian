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
        echo "Created session directory at: " . g:visidian_session_dir
    endif
endfunction

function! visidian#get_session_file() abort
    let safe_name = substitute(g:visidian_vault_path, '[\/]', '_', 'g')
    return g:visidian_session_dir . safe_name . '.vim'
endfunction

function! visidian#get_session_history_file() abort
    let safe_name = substitute(g:visidian_vault_path, '[\/]', '_', 'g')
    return g:visidian_session_dir . safe_name . '.history'
endfunction

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

function! visidian#list_sessions() abort
    let history_file = visidian#get_session_history_file()
    if !filereadable(history_file)
        echo "No session history found."
        return []
    endif
    
    let sessions = readfile(history_file)
    if empty(sessions)
        echo "No sessions in history."
        return []
    endif
    
    echo "Available sessions (most recent first):"
    let i = 0
    for session in sessions
        let session_data = json_decode(session)
        let timestamp = strftime('%Y-%m-%d %H:%M:%S', session_data.timestamp)
        echo printf('%d: %s - Last note: %s', 
            \ i, 
            \ timestamp, 
            \ empty(session_data.last_note) ? '[none]' : fnamemodify(session_data.last_note, ':t'))
        let i += 1
    endfor
    
    return sessions
endfunction

function! visidian#choose_session() abort
    let sessions = visidian#list_sessions()
    if empty(sessions)
        return 0
    endif
    
    let choice = input('Enter session number (0-' . (len(sessions)-1) . ') or [Enter] to cancel: ')
    if empty(choice)
        echo "\nCancelled."
        return 0
    endif
    
    let choice_num = str2nr(choice)
    if choice_num < 0 || choice_num >= len(sessions)
        echohl ErrorMsg
        echo "\nInvalid session number."
        echohl None
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

function! visidian#clear_sessions() abort
    let history_file = visidian#get_session_history_file()
    if !filereadable(history_file)
        echo "No session history to clear."
        return
    endif
    
    let choice = input('Clear all session history? [y/N]: ')
    if choice =~? '^y'
        call delete(history_file)
        echo "\nSession history cleared."
    else
        echo "\nOperation cancelled."
    endif
endfunction

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
        
        echo "Session saved to: " . session_file
        return 1
    endif
    return 0
endfunction

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
            
            echo "Session loaded from: " . session_file
            return 1
        else
            echo "No existing session found at: " . session_file
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
        echohl WarningMsg
        echo "No vault configured. Let's set one up!"
        echohl None
        if visidian#create_vault()
            echo "Vault created. Opening dashboard..."
        else
            echohl ErrorMsg
            echo "Failed to create vault. Please try again with :VisidianVault"
            echohl None
            return
        endif
    endif

    " Ensure vault path exists
    if !isdirectory(g:visidian_vault_path)
        echohl ErrorMsg
        echo "Vault directory does not exist: " . g:visidian_vault_path
        echo "Please create it or set a new path with :VisidianVault"
        echohl None
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
            \ '  Visidian - Obsidian for Vim',
            \ '',
            \ '  Current Vault: ' . g:visidian_vault_path,
            \ '',
            \ '  Commands:',
            \ '  [n] :VisidianFile    - New Note',
            \ '  [f] :VisidianFolder  - New Folder',
            \ '  [s] :VisidianSearch  - Search Notes',
            \ '  [l] :VisidianLink    - Link Notes',
            \ '  [p] :VisidianParaGen - Generate PARA Folders',
            \ '  [h] :VisidianHelp    - Help',
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
        return 1
    catch
        echohl ErrorMsg
        echo "Failed to write configuration to " . g:visidian_config_file . ": " . v:exception
        echohl None
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
    let para_folders = ['Projects', 'Areas', 'Resources', 'Archive']
    for folder in para_folders
        let folder_path = g:visidian_vault_path . '/' . folder
        if !isdirectory(folder_path)
            call mkdir(folder_path, 'p')
            echo "Created folder: " . folder_path
        endif
        
        " Create a README and example note in each folder
        for folder in para_folders
            " Create README
            let readme_path = g:visidian_vault_path . '/' . folder . '/README.md'
            if !filereadable(readme_path)
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
            endif

            " Create example note
            let example_path = g:visidian_vault_path . '/' . folder . '/example.md'
            if !filereadable(example_path)
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
                echo "Created example note: " . example_path
            endif
        endfor
        return 1
    endfor
    return 0
endfunction

" FUNCTION: Set up a new vault
function! visidian#create_vault() abort
    " Get vault name from user
    let vault_name = input("Enter new vault name: ")
    if empty(vault_name)
        echohl WarningMsg
        echo "No vault name provided. Vault creation cancelled."
        echohl None
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
        if !visidian#write_json({'vault_path': vault_path})
            throw "Failed to save vault configuration"
        endif
        
        echo "New vault created at " . vault_path

        " Ask about PARA folders
        echo "\nWould you like to set up PARA folders? (y/n): "
        let setup_para = nr2char(getchar())
        echo setup_para
        if setup_para =~? '^y'
            call visidian#create_para_folders()
            echo "PARA folders created with README files"
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
        echohl ErrorMsg
        echo "Failed to create vault: " . v:exception
        echohl None
        return 0
    endtry
endfunction

" FUNCTION: create popup menu
function! s:create_popup_menu()
    let commands = [
        \ {'text': 'Dashboard', 'cmd': ':VisidianDashboard', 'key': 'd'},
        \ {'text': 'New File', 'cmd': ':VisidianFile', 'key': 'f'},
        \ {'text': 'New Folder', 'cmd': ':VisidianFolder', 'key': 'o'},
        \ {'text': 'New Vault', 'cmd': ':VisidianVault', 'key': 'v'},
        \ {'text': 'Set Vault', 'cmd': ':VisidianPath', 'key': 's'},
        \ {'text': 'Link Notes', 'cmd': ':VisidianLink', 'key': 'l'},
        \ {'text': 'Search', 'cmd': ':VisidianSearch', 'key': 'e'},
        \ {'text': 'Sort', 'cmd': ':VisidianSort', 'key': 'y'},
        \ {'text': 'Generate PARA folders', 'cmd': ':VisidianParaGen', 'key': 'p'},
        \ {'text': 'Sync', 'cmd': ':VisidianSync'},
        \ {'text': 'Toggle Auto Sync', 'cmd': 'VisidianToggleAutoSync'},
        \ {'text': 'Preview On/Off', 'cmd': ':VisidianTogglePreview', 'key': 'r'},
        \ {'text': 'Help', 'cmd': ':VisidianHelp', 'key': 'h'},
        \ ]

    " Check if popup is supported
    if has('popupwin')
      let s:visidian_popup_commands = commands  " Store commands for use in callback  
      let popup = popup_create(commands, {
        \   'line': 'cursor+1',
        \   'col': 'cursor',
        \   'title': 'Visidian Commands',
        \   'filter': 'popup_filter_menu',
        \   'callback': 's:popup_callback',
        \   'border': [],
        \   'mapping': 0,
        \   'minwidth': 20,
        \   'maxwidth': 50,
        \   'zindex': 300, 
        \   'drag': 1,
        \   'resize':1,
        \   'scrollbar':1,
        \   'close': 'button'
        \ })
    else
        echo "Popup windows not supported in this Vim version."
    endif
endfunction

" FUNCTION Popup Filter
function! s:popup_filter(winid, key)
    if a:key =~? '[a-z]'  " Check if key is a letter
        let idx = index(map(copy(s:visidian_popup_commands), 'tolower(v:val.key)'), tolower(a:key))
        if idx != -1
            call popup_close(a:winid, idx + 1)
            return 1
        endif
    endif
    return popup_filter_menu(a:winid, a:key)
endfunction


" FUNCTION: Popup Callback
function! s:popup_callback(winid, result)
    if a:result > 0 && exists('s:visidian_popup_commands')
        let command = get(get(g:, 'visidian_popup_commands', []), a:result - 1, {}).cmd
        if !empty(command)
            execute command
        endif
    endif
endfunction

" FUNCTION: define menu
function! visidian#menu()
    if exists('s:popup_menu')
        call popup_close(s:popup_menu)
    endif
    let s:popup_menu = s:create_popup_menu()
endfunction

" map key to call dashboard
nnoremap <silent> <leader>v :call visidian#dashboard()<CR>

" If you want to open only the menu without the full dashboard:
nnoremap <silent> <leader>vm :call visidian#menu()<CR>

" FUNCTION: clear cache of non-existent files
function! visidian#clear_cache()
    if !exists('g:visidian_cache')
        let g:visidian_cache = {}
        return
    endif
    
    echomsg "Starting cache clear with keys: " . string(keys(g:visidian_cache))
    let new_cache = {}
    for path in keys(g:visidian_cache)
        if empty(g:visidian_vault_path)
            echoerr "Vault path not set or invalid."
            return
        endif

        let full_path = g:visidian_vault_path . file
        echomsg "Checking file: " . full_path
        if !filereadable(full_path)
            let new_cache[path] = g:visidian_cache[path]
        else
          echomsg "Removing non-existent file from cache: " . path
        endif
    endfor
    let g:visidian_cache = new_cache
    echomsg "Cache cleared to: " . string(keys(g:visidian_cache))
endfunction

" FUNCTION: Helper to cache file information, ignoring errors for missing files
function! s:cache_file_info(file)
" Ensure the file path is relative to the vault
  let file_path = substitute(a:file, '^' . g:visidian_vault_path, '', '')
  let full_path = g:visidian_vault_path . a:file
    echomsg "Caching: " . full_path
    try
        let lines = readfile(full_path)
        let yaml_start = match(lines, '^---$')
        let yaml_end = match(lines, '^---$', yaml_start + 1)
        if yaml_start != -1 && yaml_end != -1
            let g:visidian_cache[a:file] = {
            \   'yaml': lines[yaml_start+1 : yaml_end-1]
            \}
        echomsg "Added to cache: " . a:file
        else
            let g:visidian_cache[a:file] = {'yaml': []}
            echomsg "Added empty YAML to cache: " . a:file
        endif
    catch /^Vim\%((\a\+)\)\=:E484/
        echomsg "File not found, removing from cache: " . a:file 
        " Ignore errors for files that no longer exist
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
            echo "No vault name provided."
        endif
    catch /^Vim\%((\a\+)\)\=:E739/
        echoerr "Cannot create directory: Permission denied."
    endtry
endfunction

" FUNCTION: Call Create a new markdown file (with YAML front matter)

function! visidian#new_md_file()
    call visidian#file_creation#new_md_file()
endfunction


" FUNCTION: Call Markdown Preview
function! visidian#toggle_preview()
    call visidian#preview#toggle_preview()
endfunction

" FUNCTION: Create a new folder
function! visidian#new_folder()
    let folder_name = input("Enter new folder name: ")
    if folder_name != ''
        let full_path = g:visidian_vault_path . folder_name
        call mkdir(full_path, 'p')
        echo "Folder created at " . full_path
    else
        echo "No folder name provided."
    endif
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
        echoerr "No vault path set. Please create or set a vault first."
        return
    endif

    let para_folders = ['projects', 'areas', 'resources', 'archives']
    for folder in para_folders
        try
            call mkdir(g:visidian_vault_path . folder, 'p')
            echo "Created folder: " . folder
        catch /^Vim\%((\a\+)\)\=:E739/
            echoerr "Error creating folder " . folder . ": Permission denied."
        endtry
    endfor
endfunction

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

    echoerr "Help file for Visidian not found in any expected locations."
endfunction

" FUNCTION: Call Sync
function! visidian#sync()
    call visidian#sync#sync()
endfunction

" FUNCTIONS TO START AND STOP THE AUTO-SYNC TIMER 

" First Version check for auto-sync functionality
if v:version >= 800
    function! visidian#toggle_auto_sync()
        if exists('s:auto_sync_timer')
            call timer_stop(s:auto_sync_timer)
            unlet s:auto_sync_timer
            echo "Auto-sync stopped."
        else
            let s:auto_sync_timer = timer_start(3600000, function('s:AutoSyncCallback'), {'repeat': -1})
            echo "Auto-sync started. Syncing every hour."
        endif
    endfunction

    function! s:AutoSyncCallback(timer)
        call visidian#sync()
        echo "Auto-sync performed."
    endfunction
else
    " Fallback for versions < 8.0
    let s:last_sync_time = 0
    function! s:CheckForSync()
        if !exists('s:last_sync_time') || localtime() - s:last_sync_time > 3600 " 3600 seconds = 1 hour
            let s:last_sync_time = localtime()
            call visidian#sync()
            echo "Periodic sync performed."
        endif
    endfunction

    augroup VisidianSyncAuto
        autocmd!
        autocmd CursorHold * call s:CheckForSync()
    augroup END
endif

" Auto-save session on exit
augroup VisidianSession
    autocmd!
    autocmd VimLeave * call visidian#save_session()
augroup END
