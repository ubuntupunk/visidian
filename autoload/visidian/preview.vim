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

"FUNCTION: preview toggle
function! visidian#preview#toggle_preview()
    call s:debug_msg("Current filetype: " . &filetype)
    call s:debug_msg("Current buffer: " . bufname('%'))
    
    if &filetype != 'markdown'
        call s:debug_msg("Not a markdown file, aborting")
        echo "This command only works with Markdown files."
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

    " Finally, clean up the preview buffer if it exists
    if exists('s:preview_buf') && bufexists(s:preview_buf)
        call s:debug_msg("Cleaning up preview buffer: " . s:preview_buf)
        " Try to close any associated windows first
        let winids = win_findbuf(s:preview_buf)
        for winid in winids
            call s:debug_msg("Closing window: " . winid)
            call win_execute(winid, 'close')
        endfor
        " Then delete the buffer
        execute 'bd! ' . s:preview_buf
        unlet s:preview_buf
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

    " Create a new vertical split on the right
    call s:debug_msg("Creating preview buffer")
    botright vnew
    let s:preview_buf = bufnr('%')
    call s:debug_msg("Created preview buffer: " . s:preview_buf)
    
    " Set up the buffer
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal nofoldenable
    setlocal nonumber
    setlocal norelativenumber
    
    " Start grip in the background
    let current_file = expand('#' . bufnr('#') . ':p')
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

    " Set the window size
    vertical resize 50
    
    " Add a status line to the preview window
    setlocal statusline=%=%{exists('s:preview_active')?'Preview\ Active':'Preview\ Starting'}

    " Wait a bit for grip to start
    call s:debug_msg("Waiting for grip to start")
    sleep 500m
    
    " Try to load the preview content
    call s:load_preview_content()
    
    let s:preview_active = 1
    call s:debug_msg("Grip preview started successfully")
    echo "Markdown preview started with grip."
endfunction

" FUNCTION: Load Preview Content
function! s:load_preview_content()
    call s:debug_msg("Loading preview content")
    
    if !exists('s:preview_buf') || !bufexists(s:preview_buf)
        call s:debug_msg("Preview buffer not found")
        return
    endif
    
    " Load the preview URL in the buffer
    let url = 'http://0.0.0.0:6419'
    call s:debug_msg("Fetching content from: " . url)
    
    if executable('curl')
        let content = system('curl -s ' . url)
        if v:shell_error == 0
            call s:debug_msg("Content fetched successfully")
            call setbufvar(s:preview_buf, '&modifiable', 1)
            call deletebufline(s:preview_buf, 1, '$')
            call setbufline(s:preview_buf, 1, split(content, '\n'))
            call setbufvar(s:preview_buf, '&modifiable', 0)
        else
            call s:debug_msg("Failed to fetch content: " . v:shell_error)
        endif
    else
        call s:debug_msg("curl not found")
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
