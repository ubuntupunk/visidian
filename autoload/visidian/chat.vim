" Visidian Chat
" Maintainer: ubuntupunk
" License: GPL3

" Configuration variables
if !exists('g:visidian_chat_provider')
    let g:visidian_chat_provider = 'openai'  " Options: 'openai', 'gemini', 'anthropic', 'deepseek'
endif

if !exists('g:visidian_chat_openai_key')
    let g:visidian_chat_openai_key = $OPENAI_API_KEY
endif

if !exists('g:visidian_chat_gemini_key')
    let g:visidian_chat_gemini_key = $GEMINI_API_KEY
endif

if !exists('g:visidian_chat_anthropic_key')
    let g:visidian_chat_anthropic_key = $ANTHROPIC_API_KEY
endif

if !exists('g:visidian_chat_deepseek_key')
    let g:visidian_chat_deepseek_key = $DEEPSEEK_API_KEY
endif

if !exists('g:visidian_chat_model')
    let g:visidian_chat_model = {
        \ 'openai': 'gpt-3.5-turbo',
        \ 'gemini': 'gemini-pro',
        \ 'anthropic': 'claude-3-opus',
        \ 'deepseek': 'deepseek-chat'
        \ }
endif

if !exists('g:visidian_chat_window_width')
    let g:visidian_chat_window_width = 80
endif

if !exists('g:visidian_chat_max_context_chunks')
    let g:visidian_chat_max_context_chunks = 5
endif

if !exists('g:visidian_chat_similarity_threshold')
    let g:visidian_chat_similarity_threshold = 0.7
endif

" Provider-specific API endpoints
let s:api_endpoints = {
    \ 'openai': 'https://api.openai.com/v1/chat/completions',
    \ 'gemini': 'https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent',
    \ 'anthropic': 'https://api.anthropic.com/v1/messages',
    \ 'deepseek': 'https://api.deepseek.com/v1/chat/completions'
    \ }

" Get API key based on provider
function! s:get_api_key()
    let l:provider = g:visidian_chat_provider
    if l:provider == 'openai'
        return g:visidian_chat_openai_key
    elseif l:provider == 'gemini'
        return g:visidian_chat_gemini_key
    elseif l:provider == 'anthropic'
        return g:visidian_chat_anthropic_key
    elseif l:provider == 'deepseek'
        return g:visidian_chat_deepseek_key
    endif
    throw 'Invalid provider: ' . l:provider
endfunction

" Format request payload based on provider
function! s:format_request_payload(query, context)
    let l:provider = g:visidian_chat_provider
    let l:model = g:visidian_chat_model[l:provider]
    let l:content = "Context:\n" . a:context . "\n\nQuery:\n" . a:query

    if l:provider == 'openai'
        return json_encode({
            \ 'model': l:model,
            \ 'messages': [
            \   {'role': 'system', 'content': 'You are a helpful assistant analyzing markdown notes.'},
            \   {'role': 'user', 'content': l:content}
            \ ]
            \})
    elseif l:provider == 'gemini'
        return json_encode({
            \ 'contents': [{
            \   'parts': [{'text': l:content}]
            \ }],
            \ 'generationConfig': {
            \   'temperature': 0.7,
            \   'topK': 40,
            \   'topP': 0.95,
            \   'maxOutputTokens': 2048,
            \ }
            \})
    elseif l:provider == 'anthropic'
        return json_encode({
            \ 'model': l:model,
            \ 'messages': [{
            \   'role': 'user',
            \   'content': l:content
            \ }],
            \ 'max_tokens': 2048
            \})
    elseif l:provider == 'deepseek'
        return json_encode({
            \ 'model': l:model,
            \ 'messages': [
            \   {'role': 'system', 'content': 'You are a helpful assistant analyzing markdown notes.'},
            \   {'role': 'user', 'content': l:content}
            \ ]
            \})
    endif
    throw 'Invalid provider: ' . l:provider
endfunction

" Get API headers based on provider
function! s:get_api_headers()
    let l:provider = g:visidian_chat_provider
    let l:api_key = s:get_api_key()
    
    if l:provider == 'openai'
        return [
            \ 'Content-Type: application/json',
            \ 'Authorization: Bearer ' . l:api_key
            \ ]
    elseif l:provider == 'gemini'
        return [
            \ 'Content-Type: application/json',
            \ 'x-goog-api-key: ' . l:api_key
            \ ]
    elseif l:provider == 'anthropic'
        return [
            \ 'Content-Type: application/json',
            \ 'x-api-key: ' . l:api_key,
            \ 'anthropic-version: 2023-06-01'
            \ ]
    elseif l:provider == 'deepseek'
        return [
            \ 'Content-Type: application/json',
            \ 'Authorization: Bearer ' . l:api_key
            \ ]
    endif
    throw 'Invalid provider: ' . l:provider
endfunction

" Parse response based on provider
function! s:parse_response(response)
    let l:provider = g:visidian_chat_provider
    let l:json_response = json_decode(a:response)

    if l:provider == 'openai'
        return l:json_response.choices[0].message.content
    elseif l:provider == 'gemini'
        return l:json_response.candidates[0].content.parts[0].text
    elseif l:provider == 'anthropic'
        return l:json_response.content[0].text
    elseif l:provider == 'deepseek'
        return l:json_response.choices[0].message.content
    endif
    throw 'Invalid provider: ' . l:provider
endfunction

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
    
    " Get context from vector store based on current content
    let l:relevant_chunks = visidian#vectorstore#find_relevant_notes(l:current_content, g:visidian_chat_max_context_chunks)
    
    " Filter chunks by similarity threshold
    let l:filtered_chunks = filter(l:relevant_chunks, {_, v -> v.similarity >= g:visidian_chat_similarity_threshold})
    
    " Build context with current content and relevant chunks
    let l:context = "Current note:\n" . l:current_content . "\n\n"
    
    if !empty(l:filtered_chunks)
        let l:context .= "Relevant context from other notes:\n\n"
        for l:chunk in l:filtered_chunks
            let l:context .= "From " . fnamemodify(l:chunk.file_path, ':t') . ":\n"
            let l:context .= l:chunk.chunk . "\n\n"
        endfor
    endif
    
    return l:context
endfunction

" Index current note in vector store
function! visidian#chat#index_current_note() abort
    let l:current_file = expand('%:p')
    if !empty(l:current_file) && &filetype == 'markdown'
        call visidian#vectorstore#store_note(l:current_file)
        echo "Note indexed in vector store"
    endif
endfunction

" Index entire vault
function! visidian#chat#index_vault() abort
    let l:vault_path = get(g:, 'visidian_vault_path', expand('%:p:h'))
    echo "Indexing vault... This may take a while"
    
    for l:file in glob(l:vault_path . '/**/*.md', 0, 1)
        echo "Indexing " . fnamemodify(l:file, ':t')
        call visidian#vectorstore#store_note(l:file)
    endfor
    
    echo "Vault indexing complete"
endfunction

" Add autocommands for automatic indexing
augroup VisidianVectorStore
    autocmd!
    autocmd BufWritePost *.md call visidian#chat#index_current_note()
augroup END

function! visidian#chat#send_to_llm(query, context) abort
    if empty(s:get_api_key())
        throw 'Visidian Chat Error: API key not set for provider ' . g:visidian_chat_provider
    endif
    
    let l:payload = s:format_request_payload(a:query, a:context)
    let l:headers = s:get_api_headers()
    let l:endpoint = s:api_endpoints[g:visidian_chat_provider]
    
    let l:cmd = ['curl', '-s', '-X', 'POST']
    for l:header in l:headers
        call add(l:cmd, '-H')
        call add(l:cmd, l:header)
    endfor
    call extend(l:cmd, ['-d', l:payload, l:endpoint])
    
    let l:response = system(join(l:cmd, ' '))
    
    if v:shell_error
        throw 'Visidian Chat Error: API request failed: ' . l:response
    endif
    
    try
        return s:parse_response(l:response)
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