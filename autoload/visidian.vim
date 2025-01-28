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

" FUNCTION: Helper function to manage sessions
function! s:ensure_session_dir()
    if !isdirectory(g:visidian_session_dir)
        call mkdir(g:visidian_session_dir, 'p')
    endif
endfunction

function! s:get_session_file()
    return g:visidian_session_dir . substitute(g:visidian_vault_path, '[\/]', '_', 'g') . '.vim'
endfunction

function! s:save_session()
    if g:visidian_auto_save_session && !empty(g:visidian_vault_path)
        call s:ensure_session_dir()
        let session_file = s:get_session_file()
        execute 'mksession! ' . session_file
    endif
endfunction

function! s:load_session()
    if !empty(g:visidian_vault_path)
        let session_file = s:get_session_file()
        if filereadable(session_file)
            execute 'source ' . session_file
            return 1
        endif
    endif
    return 0
endfunction

" FUNCTION: Load the vault path from JSON or prompt for one 
function! visidian#load_vault_path()
    if !exists('g:visidian_vault_path') || g:visidian_vault_path == ''
        let json_data = s:read_json()
        if has_key(json_data, 'vault_path')
           let safe_path = visidian#ensure_home_directory(json_data['vault_path'])
            if !empty(safe_path)
                let g:visidian_vault_path = safe_path
            else
                call visidian#set_vault_path()
            endif
        else
            " If no path found, prompt for one or handle accordingly
            call visidian#set_vault_path()
        endif
    endif
    " Ensure path is safe even if set manually
    let g:visidian_vault_path = visidian#ensure_home_directory(g:visidian_vault_path)
endfunction 


" FUNCTION: Set the vault path, either from cache, .visidian.json, or new input
function! visidian#set_vault_path()
    " Check if vault path is already cached
    if exists('g:visidian_vault_path') && g:visidian_vault_path != ''
        return
    endif

" Try to read from .visidian.json

"    let json_data = s:read_json()
"    if has_key(json_data, 'vault_path')
"        let g:visidian_vault_path = json_data['vault_path']
"        " Ensure there's exactly one trailing slash for consistency
"        if g:visidian_vault_path[-1:] != '/'
"            let g:visidian_vault_path .= '/'
"        endif
"        return
"    endif

" If no cache or JSON file, prompt user for vault path
    let vault_name = input("Enter existing vault name or path: ")
    if vault_name != ''
        let g:visidian_vault_path = expand(vault_name . '/')
        " Save to JSON for future use
        call s:write_json({'vault_path': g:visidian_vault_path})
    else
        echo "No vault path provided."
    endif
endfunction

" FUNCTION: Main dashboard
function! visidian#dashboard()
    call visidian#load_vault_path() " Ensure vault path is set
    if g:visidian_vault_path == ''
        echoerr "No vault path set. Please create a vault first."
        return
    endif

    " Try to load existing session first
    if s:load_session()
        return
    endif

    " If no session exists, set up a new dashboard
    enew
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    
    " Set up dashboard layout
    let header = [
        \ '  Visidian - Obsidian for Vim',
        \ '',
        \ '  [n] New Note',
        \ '  [f] New Folder',
        \ '  [s] Search Notes',
        \ '  [l] Link Notes',
        \ '  [h] Help',
        \ '  [q] Quit',
        \ ''
        \ ]
    
    call append(0, header)
    normal! gg
    setlocal nomodifiable
    
    " Save initial session
    call s:save_session()

    " Check if NERDTree is installed, use 'silent' to suppress NERDTree messages
    " if used
    if exists(":NERDTree")
         exe 'NERDTree ' . g:visidian_vault_path
         " Bookmark the last opened note if bookmarking is enabled
        if g:visidian_bookmark_last_note
            call visidian#bookmarking#bookmark_last_note()
        endif
    else
    " Use Vim's built-in Explore as a fallback
         exe 'Explore ' . g:visidian_vault_path
    endif

    " Only split if not already in a dashboard buffer    
   " if &buftype != 'nofile' || expand('%:t') != 'VisidianDashboard'
    vsplit 
   " endif

    " Set up the dashboard buffer
   " setlocal buftype=nofile bufhidden=hide noswapfile nowrap
    setlocal modifiable
   " silent %delete _

    " Frame the buffer to indicate Visidian dashboard
    call append(0, repeat('=', 50))
    call append(1, ' Visidian Dashboard')
    call append(2, repeat('=', 50))
    "call append(3, 'Vault: ' . g:visidian_vault_path)
    call append(3, '') 

    " Add some useful information or commands here if needed
    if exists(":NERDTree")
        call append(4, ' - Navigate using NERDTree')
    else
        call append(4, ' - Navigate using Netrw')
    endif
    call append(5, ' - Use :VisidianMenu to call PopUp Menu')
    call append(6, ' - Use :VisidianFile for new notes')
    call append(7, ' - Use :VisidianFolder for new folders')
    call append(8, ' - Use :VisidianVault for new vaults')
    call append(9, ' - Use :VisidianParaGen to setup PARA')
    call append(10, ' - Use :VisidianDash to refresh this buffer')
    call append(11, ' - Use q to close this buffer')
    call append(12, ' - Use :VisidianHelp for more information')
    call append(13, ' - set mouse=a to enable mouse support')

    setlocal nomodifiable
    nnoremap <buffer> <silent> q :bd<CR>  " Close the dashboard buffer with 'q'

    " Populate cache, ignoring non-existant files
    call visidian#clear_cache()  " Clear old cache entries
    echomsg "Cache after clear: " . string(g:visidian_cache)
    let files = globpath(g:visidian_vault_path, '**/*.md', 0, 1)
    echomsg "Files found: " . string(files)
    for file in files
        call s:cache_file_info(file)
    endfor
" Create a popup menu for Visidian commands
    call s:create_popup_menu()
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
        \ {'text': 'Bookmarks On/Off', 'cmd': ':VisidianToggleBookmarking', 'key': 'b'}, 
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
            call s:write_json({'vault_path': g:visidian_vault_path})
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
    autocmd VimLeave * call s:save_session()
augroup END
