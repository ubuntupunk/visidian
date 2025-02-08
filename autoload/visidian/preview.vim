"This is the markdown preview functionality for Vim. It uses
"markdown-preview.nvim if available, otherwise it falls back to using grip.
"Requires Vim 8.1 or Neovim.

" Initialize debug mode
let s:debug = get(g:, 'visidian_debug', 0)

" Internal debug function
function! s:debug_msg(msg)
    if s:debug
        echom "Visidian Preview: " . a:msg
    endif
endfunction

" FUNCTION: Open URL in browser
function! s:open_in_browser(url)
    call s:debug_msg("Opening URL in browser: " . a:url)
    
    if has('unix')
        let browsers = ['xdg-open', 'google-chrome', 'firefox', 'chromium']
        let cmd = ''
        for browser in browsers
            if executable(browser)
                let cmd = browser
                break
            endif
        endfor
        
        if empty(cmd)
            call s:debug_msg("No browser found")
            echo "Error: No suitable browser found"
            return 0
        endif
        
        call system(cmd . ' ' . a:url . ' &')
        return 1
    elseif has('win32') || has('win64')
        call system('start ' . a:url)
        return 1
    elseif has('mac') || has('macunix')
        call system('open ' . a:url)
        return 1
    endif
    
    return 0
endfunction

"FUNCTION: preview toggle
function! visidian#preview#toggle_preview()
    call s:debug_msg("Current filetype: " . &filetype)
    call s:debug_msg("Current buffer: " . bufname('%'))
    
    if &filetype != 'markdown' && &filetype != 'visidian'
        call s:debug_msg("Not a markdown or visidian file, aborting")
        echo "This command only works with Markdown or Visidian files."
        return
    endif

    call s:debug_msg("Toggle preview called for filetype: " . &filetype)
    
    if exists('s:preview_active') && s:preview_active
        call s:debug_msg("Stopping active preview")
        call s:stop_preview()
    else
        call s:debug_msg("Starting preview")
        if s:supports_markdown_preview()
            if exists(':MarkdownPreview')
                call s:debug_msg("Using markdown-preview.nvim")
                MarkdownPreview
                let s:preview_active = 1
                echo "Markdown preview started using markdown-preview.nvim."
            elseif exists(':InstantMarkdownPreview')
                call s:debug_msg("Using instant-markdown-vim")
                InstantMarkdownPreview
                let s:preview_active = 1
                echo "Markdown preview started using instant-markdown-vim."
            else
                call s:debug_msg("No plugin preview available, using grip")
                echo "Neither markdown-preview.nvim nor instant-markdown-vim available. Using grip..."
                call s:start_grip_preview()
            endif
        else
            call s:debug_msg("Vim version doesn't support plugin preview, using grip")
            call s:start_grip_preview()
        endif
    endif
endfunction

"FUNCTION: Stop Preview
function! s:stop_preview()
    call s:debug_msg("Stopping preview")
    
    " First try to stop any running grip processes
    if exists('s:grip_job')
        call s:debug_msg("Stopping grip job")
        if has('nvim')
            call jobstop(s:grip_job)
        else
            call job_stop(s:grip_job)
        endif
        unlet s:grip_job
    endif

    " Then try to stop plugin previews
    if exists(':MarkdownPreviewStop')
        call s:debug_msg("Stopping markdown-preview.nvim")
        MarkdownPreviewStop
    elseif exists(':InstantMarkdownStop')
        call s:debug_msg("Stopping instant-markdown-vim")
        InstantMarkdownStop
    endif

    let s:preview_active = 0
    call s:debug_msg("Preview stopped")
    echo "Markdown preview stopped."
endfunction

" FUNCTION: Start GRIP Preview
function! s:start_grip_preview()
    call s:debug_msg("Starting grip preview")
    
    if !executable('grip')
        call s:debug_msg("grip not found")
        let install = confirm("grip not found. Would you like to install it?", "&Yes\n&No", 1)
        if install == 1
            echo "Please run 'pip install grip' to install grip."
        else
            echo "No preview available. Please install grip for preview functionality."
        endif
        return
    endif

    " Stop any existing preview first
    call s:stop_preview()

    " Start grip in the background
    let current_file = expand('%:p')
    let cmd = ['grip', current_file, '0.0.0.0:6419', '--quiet']
    call s:debug_msg("Starting grip with command: " . string(cmd))
    
    if has('nvim')
        let s:grip_job = jobstart(cmd, {
            \ 'on_exit': {job_id, data, event -> s:on_grip_exit(job_id, data, event)}
            \ })
        call s:debug_msg("Started Neovim job: " . s:grip_job)
    else
        let s:grip_job = job_start(cmd, {
            \ 'exit_cb': {job, status -> s:on_grip_exit_vim(job, status)}
            \ })
        call s:debug_msg("Started Vim job: " . string(s:grip_job))
    endif

    " Wait a bit for grip to start
    call s:debug_msg("Waiting for grip to start")
    sleep 1000m
    
    " Open in browser
    let url = 'http://localhost:6419'
    if s:open_in_browser(url)
        let s:preview_active = 1
        call s:debug_msg("Grip preview started successfully")
        echo "Markdown preview started in browser."
    else
        call s:debug_msg("Failed to open browser")
        echo "Error: Could not open browser for preview."
        call s:stop_preview()
    endif
endfunction

" FUNCTION: Grip Exit Callback for Neovim
function! s:on_grip_exit(job_id, data, event) dict
    call s:debug_msg("Neovim grip process exited with status: " . a:data)
    if exists('s:preview_active') && s:preview_active
        echo "Grip preview stopped unexpectedly"
        call s:stop_preview()
    endif
endfunction

" FUNCTION: Grip Exit Callback for Vim
function! s:on_grip_exit_vim(job, status) dict
    call s:debug_msg("Vim grip process exited with status: " . a:status)
    if exists('s:preview_active') && s:preview_active
        echo "Grip preview stopped unexpectedly"
        call s:stop_preview()
    endif
endfunction

"FUNCTION: Check if Vim supports either MarkdownPreview or InstantMarkdownPreview
function! s:supports_markdown_preview()
    let supported = v:version >= 801 || has('nvim')
    call s:debug_msg("Markdown preview plugin support: " . supported)
    return supported
endfunction
