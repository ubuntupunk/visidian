" Visidian Chat
" Maintainer: ubuntupunk
" License: GPL3

" Configuration variables
if !exists('g:visidian_chat_api_key')
    let g:visidian_chat_api_key = $OPENAI_API_KEY
endif

if !exists('g:visidian_chat_model')
    let g:visidian_chat_model = 'gpt-3.5-turbo'
endif

if !exists('g:visidian_chat_window_width')
    let g:visidian_chat_window_width = 80
endif

" Create a new vertical split window for the chat
function! visidian#chat#create_window() abort
    execute 'vertical rightbelow new'
    execute 'vertical resize ' . g:visidian_chat_window_width
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal filetype=markdown
    setlocal wrap
    setlocal nonumber
    setlocal norelativenumber
    setlocal noswapfile
    setlocal nomodifiable
    
    " Set buffer name
    let l:bufname = 'Visidian Chat'
    execute 'file ' . l:bufname
    
    " Buffer-local mappings
    nnoremap <buffer> q :q<CR>
    nnoremap <buffer> <CR> :call visidian#chat#send_message()<CR>
    
    return bufnr('%')
endfunction

function! visidian#chat#get_markdown_context() abort
    let l:current_content = join(getline(1, '$'), "\n")
    
    " Get linked files from markdown links [[file]]
    let l:linked_files = []
    let l:pattern = '\[\[\([^\]]\+\)\]\]'
    let l:start = 0
    
    while 1
        let l:match = matchstr(l:current_content, l:pattern, l:start)
        if empty(l:match)
            break
        endif
        
        let l:filename = substitute(l:match, '\[\[\([^\]]\+\)\]\]', '\1', '')
        let l:filepath = expand('%:p:h') . '/' . l:filename . '.md'
        
        if filereadable(l:filepath)
            call add(l:linked_files, l:filepath)
        endif
        
        let l:start = l:start + len(l:match)
    endwhile
    
    " Combine content from linked files
    let l:context = l:current_content
    for l:file in l:linked_files
        let l:context .= "\n\nLinked file " . l:file . ":\n"
        let l:context .= join(readfile(l:file), "\n")
    endfor
    
    return l:context
endfunction

function! visidian#chat#send_to_llm(query, context) abort
    if empty(g:visidian_chat_api_key)
        throw 'Visidian Chat Error: API key not set. Please set g:visidian_chat_api_key or OPENAI_API_KEY environment variable.'
    endif
    
    let l:full_prompt = json_encode({
        \ 'model': g:visidian_chat_model,
        \ 'messages': [
        \   {'role': 'system', 'content': 'You are a helpful assistant analyzing markdown notes.'},
        \   {'role': 'user', 'content': "Context:\n" . a:context . "\n\nQuery:\n" . a:query}
        \ ]
        \})
    
    let l:cmd = ['curl', '-s', '-X', 'POST',
        \ '-H', 'Content-Type: application/json',
        \ '-H', 'Authorization: Bearer ' . g:visidian_chat_api_key,
        \ '-d', l:full_prompt,
        \ 'https://api.openai.com/v1/chat/completions']
    
    let l:response = system(join(l:cmd, ' '))
    
    if v:shell_error
        throw 'Visidian Chat Error: API request failed: ' . l:response
    endif
    
    try
        let l:json_response = json_decode(l:response)
        return l:json_response.choices[0].message.content
    catch
        throw 'Visidian Chat Error: Failed to parse API response: ' . v:exception
    endtry
endfunction

function! visidian#chat#display_response(response) abort
    let l:bufnr = bufnr('Visidian Chat')
    if l:bufnr == -1
        let l:bufnr = visidian#chat#create_window()
    endif
    
    " Make buffer modifiable
    call setbufvar(l:bufnr, '&modifiable', 1)
    
    " Clear buffer and add response
    call deletebufline(l:bufnr, 1, '$')
    call setbufline(l:bufnr, 1, split(a:response, '\n'))
    
    " Make buffer unmodifiable again
    call setbufvar(l:bufnr, '&modifiable', 0)
    
    " Focus the chat window
    execute bufwinnr(l:bufnr) . 'wincmd w'
endfunction

function! visidian#chat#send_message() abort
    try
        let l:context = visidian#chat#get_markdown_context()
        let l:query = input('Enter your query: ')
        
        if empty(l:query)
            return
        endif
        
        echo "\nProcessing..."
        let l:response = visidian#chat#send_to_llm(l:query, l:context)
        call visidian#chat#display_response(l:response)
    catch
        echohl ErrorMsg
        echomsg v:exception
        echohl None
    endtry
endfunction

" Map a key to open the chat window
if !hasmapto('<Plug>VisidianChatOpen')
    nmap <unique> <Leader>cc <Plug>VisidianChatOpen
endif
nnoremap <unique> <Plug>VisidianChatOpen :call visidian#chat#create_window()<CR>