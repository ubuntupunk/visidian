"This is the markdown preview functionality for Vim. It uses
"markdown-preview.nvim if available, otherwise it falls back to using grip.
"Requires Vim 8.1 or Neovim.

"FUNCTION: preview toggle
function! visidian#preview#toggle_preview()
    if &filetype != 'markdown'
        echo "This command only works with Markdown files."
        return
    endif

    if exists('s:preview_active') && s:preview_active
        call s:stop_preview()
    else
        if s:supports_markdown_preview()
            if exists(':MarkdownPreview')
                MarkdownPreview
                let s:preview_active = 1
                echo "Markdown preview started using markdown-preview.nvim."
            elseif exists(':InstantMarkdownPreview')
                InstantMarkdownPreview
                let s:preview_active = 1
                echo "Markdown preview started using instant-markdown-vim."
            else
                echo "Neither markdown-preview.nvim nor instant-markdown-vim available. Using grip..."
                call s:start_grip_preview()
            endif
        else
            call s:start_grip_preview()
        endif
    endif
endfunction

"FUNCTION: Stop Preview
function! s:stop_preview()
    " First try to stop any running grip processes
    if exists('s:grip_job')
        if has('nvim')
            call jobstop(s:grip_job)
        else
            call job_stop(s:grip_job)
        endif
        unlet s:grip_job
    endif

    " Then try to stop plugin previews
    if exists(':MarkdownPreviewStop')
        MarkdownPreviewStop
    elseif exists(':InstantMarkdownStop')
        InstantMarkdownStop
    endif

    " Finally, clean up the preview buffer if it exists
    if exists('s:preview_buf') && bufexists(s:preview_buf)
        " Try to close any associated windows first
        let winids = win_findbuf(s:preview_buf)
        for winid in winids
            call win_execute(winid, 'close')
        endfor
        " Then delete the buffer
        execute 'bd! ' . s:preview_buf
        unlet s:preview_buf
    endif

    let s:preview_active = 0
    echo "Markdown preview stopped."
endfunction

" FUNCTION: Start GRIP Preview
function! s:start_grip_preview()
    if !executable('grip')
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
    botright vnew
    let s:preview_buf = bufnr('%')
    
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
    let cmd = ['grip', expand('#' . bufnr('#') . ':p'), '0.0.0.0:6419', '--quiet']
    
    if has('nvim')
        let s:grip_job = jobstart(cmd, {
            \ 'on_exit': {job_id, data, event -> s:on_grip_exit(job_id, data, event)}
            \ })
    else
        let s:grip_job = job_start(cmd, {
            \ 'exit_cb': {job, status -> s:on_grip_exit_vim(job, status)}
            \ })
    endif

    " Set the window size
    vertical resize 50
    
    " Add a status line to the preview window
    setlocal statusline=%=%{exists('s:preview_active')?'Preview\ Active':'Preview\ Starting'}

    " Wait a bit for grip to start
    sleep 500m
    
    " Try to load the preview in the buffer
    call s:load_preview_content()
    
    let s:preview_active = 1
    echo "Markdown preview started with grip."
endfunction

" FUNCTION: Load Preview Content
function! s:load_preview_content()
    if !exists('s:preview_buf') || !bufexists(s:preview_buf)
        return
    endif
    
    " Load the preview URL in the buffer
    let url = 'http://0.0.0.0:6419'
    
    if executable('curl')
        let content = system('curl -s ' . url)
        if v:shell_error == 0
            call setbufvar(s:preview_buf, '&modifiable', 1)
            call deletebufline(s:preview_buf, 1, '$')
            call setbufline(s:preview_buf, 1, split(content, '\n'))
            call setbufvar(s:preview_buf, '&modifiable', 0)
        endif
    endif
endfunction

" FUNCTION: Grip Exit Callback for Neovim
function! s:on_grip_exit(job_id, data, event) dict
    if exists('s:preview_active') && s:preview_active
        echo "Grip preview stopped unexpectedly"
        call s:stop_preview()
    endif
endfunction

" FUNCTION: Grip Exit Callback for Vim
function! s:on_grip_exit_vim(job, status) dict
    if exists('s:preview_active') && s:preview_active
        echo "Grip preview stopped unexpectedly"
        call s:stop_preview()
    endif
endfunction

"FUNCTION: Check if Vim supports either MarkdownPreview or InstantMarkdownPreview
function! s:supports_markdown_preview()
    return v:version >= 801 || has('nvim')
endfunction
