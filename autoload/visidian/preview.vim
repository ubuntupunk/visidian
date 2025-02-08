"This is the markdown preview functionality for Vim. It uses
"markdown-preview.nvim if available, otherwise it falls back to using grip,
"and finally bracey.vim as a last resort for HTML preview.
"Requires Vim 8.1 or Neovim.

" FUNCTION: Open URL in browser
function! s:open_in_browser(url)
    call visidian#debug#debug('PREVIEW', 'Opening URL in browser: ' . a:url)
    
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
            call visidian#debug#error('PREVIEW', 'No suitable browser found')
            echohl ErrorMsg
            echo "Error: No suitable browser found"
            echohl None
            return 0
        endif
        
        call system(cmd . ' ' . a:url . ' &')
        call visidian#debug#info('PREVIEW', 'Opened in browser using: ' . cmd)
        return 1
    elseif has('win32') || has('win64')
        call system('start ' . a:url)
        call visidian#debug#info('PREVIEW', 'Opened in Windows browser')
        return 1
    elseif has('mac') || has('macunix')
        call system('open ' . a:url)
        call visidian#debug#info('PREVIEW', 'Opened in macOS browser')
        return 1
    endif
    
    call visidian#debug#error('PREVIEW', 'Unsupported platform for browser opening')
    return 0
endfunction

"FUNCTION: preview toggle
function! visidian#preview#toggle_preview()
    call visidian#debug#debug('PREVIEW', 'Toggle preview requested. Current filetype: ' . &filetype)
    
    if &filetype != 'markdown' && &filetype != 'visidian'
        call visidian#debug#warn('PREVIEW', 'Not a markdown or visidian file, preview not available')
        echohl WarningMsg
        echo "This command only works with Markdown or Visidian files."
        echohl None
        return
    endif
    
    call visidian#debug#debug('PREVIEW', 'Toggle preview called for filetype: ' . &filetype)
    
    if exists('s:preview_active') && s:preview_active
        call visidian#debug#debug('PREVIEW', 'Stopping active preview')
        call s:stop_preview()
    else
        call visidian#debug#debug('PREVIEW', 'Starting preview')
        if s:supports_markdown_preview()
            if exists(':MarkdownPreview')
                call visidian#debug#info('PREVIEW', 'Using markdown-preview.nvim')
                MarkdownPreview
                let s:preview_active = 1
                echo "Markdown preview started using markdown-preview.nvim."
            else
                call visidian#debug#debug('PREVIEW', 'markdown-preview.nvim not found, trying grip')
                call s:start_grip_preview()
            endif
        else
            call visidian#debug#debug('PREVIEW', 'Vim version doesn''t support plugin preview, using grip')
            call s:start_grip_preview()
        endif
    endif
endfunction

"FUNCTION: Stop Preview
function! s:stop_preview()
    call visidian#debug#debug('PREVIEW', 'Stopping preview')
    
    " First try to stop any running grip processes
    if exists('s:grip_job')
        call visidian#debug#debug('PREVIEW', 'Stopping grip job')
        if has('nvim')
            call jobstop(s:grip_job)
        else
            call job_stop(s:grip_job)
        endif
        unlet s:grip_job
    endif

    " Then try to stop plugin previews
    if exists(':MarkdownPreviewStop')
        call visidian#debug#debug('PREVIEW', 'Stopping markdown-preview.nvim')
        MarkdownPreviewStop
    elseif exists(':BraceyStop')
        call visidian#debug#debug('PREVIEW', 'Stopping bracey.vim')
        BraceyStop
        unlet s:using_bracey
    endif

    let s:preview_active = 0
    call visidian#debug#debug('PREVIEW', 'Preview stopped')
    echo "Markdown preview stopped."
endfunction

" FUNCTION: Start GRIP Preview
function! s:start_grip_preview()
    call visidian#debug#debug('PREVIEW', 'Starting grip preview')
    
    if !executable('grip')
        call visidian#debug#error('PREVIEW', 'grip not found')
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
    call visidian#debug#debug('PREVIEW', 'Starting grip with command: ' . string(cmd))
    
    if has('nvim')
        let s:grip_job = jobstart(cmd, {
            \ 'on_exit': function('s:on_grip_exit')
            \ })
        call visidian#debug#debug('PREVIEW', 'Started Neovim job: ' . s:grip_job)
    else
        let s:grip_job = job_start(cmd, {
            \ 'exit_cb': function('s:on_grip_exit_vim', [])
            \ })
        call visidian#debug#debug('PREVIEW', 'Started Vim job: ' . string(s:grip_job))
    endif

    " Wait a bit for grip to start
    call visidian#debug#debug('PREVIEW', 'Waiting for grip to start')
    sleep 1000m
    
    " Open in browser
    let url = 'http://localhost:6419'
    if s:open_in_browser(url)
        let s:preview_active = 1
        call visidian#debug#debug('PREVIEW', 'Grip preview started successfully')
        echo "Markdown preview started in browser."
    else
        call visidian#debug#error('PREVIEW', 'Failed to open browser')
        echo "Error: Could not open browser for preview."
        call s:stop_preview()
    endif
endfunction

" FUNCTION: Grip Exit Callback for Neovim
function! s:on_grip_exit(job_id, data, event)
    call visidian#debug#debug('PREVIEW', 'Neovim grip process exited with status: ' . a:data)
    if exists('s:preview_active') && s:preview_active
        echo "Grip preview stopped unexpectedly"
        call s:stop_preview()
    endif
endfunction

" FUNCTION: Grip Exit Callback for Vim
function! s:on_grip_exit_vim(channel, msg)
    call visidian#debug#debug('PREVIEW', 'Vim grip process exited with status: ' . a:msg)
    if exists('s:preview_active') && s:preview_active
        echo "Grip preview stopped unexpectedly"
        call s:stop_preview()
    endif
endfunction

"FUNCTION: Check if Vim supports preview plugins
function! s:supports_markdown_preview()
    let supported = v:version >= 801 || has('nvim')
    call visidian#debug#debug('PREVIEW', 'Markdown preview plugin support: ' . supported)
    return supported
endfunction
