" Global variables
if !exists('g:visidian_cache')
    let g:visidian_cache = {}
endif
if !exists('g:visidian_vault_path')
    let g:visidian_vault_path = ''
endif
if !exists('g:visidian_vault_name')
    let g:visidian_vault_name = ''
endif
"if !exists('g:visidian#load_vault_path')
"    let g:visidian#load_vault_path = 1
"endif

" You can also add this to your vimrc or init.vim
" autocmd VimEnter * call visidian#load_vault_path()


"FUNCTION: Load the vault path from JSON or prompt for one 
function! visidian#load_vault_path()
    if !exists('g:visidian_vault_path') || g:visidian_vault_path == ''
        let json_data = s:read_json()
        if has_key(json_data, 'vault_path')
            let g:visidian_vault_path = json_data['vault_path']
        else
            " If no path found, prompt for one or handle accordingly
            call visidian#set_vault_path()
        endif
    endif
endfunction


" Commands
" FUNCTION: Helper function to cache file information
function! s:cache_file_info(file)
    let full_path = g:visidian_vault_path . a:file
    try
        let lines = readfile(full_path)
        let yaml_start = match(lines, '^---$')
        let yaml_end = match(lines, '^---$', yaml_start + 1)
        if yaml_start != -1 && yaml_end != -1
            let g:visidian_cache[a:file] = {
            \   'yaml': lines[yaml_start+1 : yaml_end-1]
            \}
        else
            let g:visidian_cache[a:file] = {'yaml': []}
        endif
    catch /^Vim\%((\a\+)\)\=:E484/
        echoerr "Error reading file: " . full_path
    endtry
endfunction

" Constants for JSON handling
let s:json_file = expand('~/.visidian.json')

" FUNCTION: Helper function to write to JSON file
function! s:write_json(data)
    let lines = ['{']
   " call add(lines, '{')
    for key in keys(a:data)
        " Ensure the JSON string is properly escaped
        let escaped_value = substitute(a:data[key], '\(["\\]\)', '\\\\\1', 'g')
        call add(lines, printf('  "%s": "%s",', key, escaped_value))
    endfor
    if !empty(lines)
        let lines[-1] = substitute(lines[-1], ',$', '', '')  " Remove trailing comma
    endif
    call add(lines, '}')
    try
        call writefile(lines, s:json_file, 'b')
    catch /^Vim\%((\a\+)\)\=:E484/
     echoerr "Error writing to " . s:json_file . ": " . v:exception
    endtry
endfunction

" FUNCTION: Helper function to read from JSON file
function! s:read_json()
  let json_file = expand('~/.visidian.json')  
  if filereadable(s:json_file)
        let lines = readfile(s:json_file)
        let data = {}
        for line in lines
            let match = matchlist(line, '\v\s*"([^"]+)":\s*"([^"]+)"')
            if !empty(match)
                let data[match[1]] = match[2]
            endif
        endfo
        return data
    endif
    return {}
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

    " Check if NERDTree is installed, use 'silent' to suppress NERDTree messages
    " if used
    if exists(":NERDTree")
         exe 'NERDTree ' . g:visidian_vault_path
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
    call append(5, ' - Use :VisidianLinkNotes to see connections')
    call append(6, ' - Use :VisidianNewFile for new notes')
    call append(7, ' - Use :VisidianNewFolder for new folders')
    call append(8, ' - Use :VisidianCreateVault for new vaults')
    call append(9, ' - Use :VisidianSetVaultPath to change vaults')
    call append(10, ' - Use :VisidianDashboard to refresh this buffer')
    call append(11, ' - Use q to close this buffer')
    call append(12, ' - Use :VisidianHelp for more information')
    call append(13, ' - set mouse=a to enable mouse support')

    setlocal nomodifiable
    nnoremap <buffer> <silent> q :bd<CR>  " Close the dashboard buffer with 'q'

    " Populate cache
    let files = globpath(g:visidian_vault_path, '**/*.md', 0, 1)
    for file in files
        call s:cache_file_info(file)
    endfor
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
        \ '$VIMRUNTIME/sources_non_forked/visidian.vim/doc/visidian_help.txt',
        \ '$HOME/.vim/plugged/visidian.vim/doc/visidian_help.txt',
        \ '$HOME/.vim/bundle/visidian.vim/doc/visidian_help.txt'
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


