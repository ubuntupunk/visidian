"This is the markdown preview functionality for Vim. It uses
"markdown-preview.nvim if available, otherwise it falls back to using grip.
"Requires Vim 8.1 or Neovim.

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
                echo "Neither markdown-preview.nvim nor instant-markdown-vim available. Trying grip..."
                call s:start_grip_preview()
            endif
        else
            call s:start_grip_preview()
        endif
    endif
endfunction

function! s:stop_preview()
    if exists(':MarkdownPreviewStop')
        MarkdownPreviewStop
    elseif exists(':InstantMarkdownStop')
        InstantMarkdownStop
    elseif exists('s:preview_buf') && bufexists(s:preview_buf)
        execute 'bd ' . s:preview_buf
        unlet s:preview_buf
    endif
    let s:preview_active = 0
    echo "Markdown preview stopped."
endfunction

function! s:start_grip_preview()
    if executable('grip')
        vsplit new
        let s:preview_buf = bufnr('%')
        setlocal buftype=terminal bufhidden=hide
        terminal grip %:p 0.0.0.0:6419 --quiet
        vertical resize 50
        let s:preview_active = 1
        echo "Markdown preview started with grip."
    else
        let install = confirm("grip not found. Would you like to install it?", "&Yes\n&No", 1)
        if install == 1
            echo "Please run 'pip install grip' to install grip."
        else
            echo "No preview available. Please install grip for preview functionality."
        endif
    endif
endfunction

" Check if Vim supports either MarkdownPreview or InstantMarkdownPreview
function! s:supports_markdown_preview()
    return v:version >= 801 || has('nvim')
endfunction
