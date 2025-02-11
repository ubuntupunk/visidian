" Visidian Chat
" Maintainer: ubuntupunk
" License: GPL3gg

" Debug logging helper
function! s:debug(msg) abort
    if exists('g:visidian_debug') && g:visidian_debug
        echom '[CHAT] ' . a:msg
    endif
endfunction
 
" Configuration variables
if !exists('g:visidian_chat_provider')
    let g:visidian_chat_provider = 'gemini'  " Options: 'openai', 'gemini', 'anthropic', 'deepseek'
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
        \ 'anthropic': 'claude-2',
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
    \ 'gemini': 'https://generativelanguage.googleapis.com/v1beta/models/' . g:visidian_chat_model['gemini'] . ':streamGenerateContent',
    \ 'anthropic': 'https://api.anthropic.com/v1/messages',
    \ 'deepseek': 'https://api.deepseek.com/v1/chat/completions'
    \ }

" Get API key based on provider
function! s:get_api_key() abort
    let l:provider = g:visidian_chat_provider
    
    " Try to get from environment first
    if l:provider == 'gemini'
        let l:env_key = $GEMINI_API_KEY
        if !empty(l:env_key)
            return l:env_key
        endif
    endif
    
    " Fall back to vim variables
    if l:provider == 'openai'
        return exists('g:visidian_chat_openai_key') ? g:visidian_chat_openai_key : $OPENAI_API_KEY
    elseif l:provider == 'gemini'
        return exists('g:visidian_chat_gemini_key') ? g:visidian_chat_gemini_key : ''
    elseif l:provider == 'anthropic'
        return exists('g:visidian_chat_anthropic_key') ? g:visidian_chat_anthropic_key : $ANTHROPIC_API_KEY
    elseif l:provider == 'deepseek'
        return exists('g:visidian_chat_deepseek_key') ? g:visidian_chat_deepseek_key : $DEEPSEEK_API_KEY
    endif
    throw 'Invalid provider: ' . l:provider
endfunction

" Get headers based on provider
function! s:get_headers() abort
    let l:provider = g:visidian_chat_provider
    let l:headers = ['Content-Type: application/json']
    let l:api_key = s:get_api_key()
    
    if empty(l:api_key)
        throw 'No API key found for provider: ' . l:provider
    endif
    
    if l:provider == 'openai'
        call add(l:headers, 'Authorization: Bearer ' . l:api_key)
    elseif l:provider == 'gemini'
        call add(l:headers, 'x-goog-api-key: ' . l:api_key)
    elseif l:provider == 'anthropic'
        call add(l:headers, 'x-api-key: ' . l:api_key)
        call add(l:headers, 'anthropic-version: 2023-06-01')
    elseif l:provider == 'deepseek'
        call add(l:headers, 'Authorization: Bearer ' . l:api_key)
    endif
    
    return l:headers
endfunction

" Process streaming response chunk
function! s:process_chunk(chunk) abort
    try
        " Clean up chunk data
        let l:clean_chunk = substitute(a:chunk, '^\s*', '', '')  " Remove leading whitespace
        let l:clean_chunk = substitute(l:clean_chunk, '\^@', '', 'g')  " Remove control chars
        
        " Check for error response
        if l:clean_chunk =~# '"error":'
            let l:error = json_decode(l:clean_chunk)
            if type(l:error) == v:t_dict && has_key(l:error, 'error')
                throw 'API Error: ' . l:error.error.message
            endif
        endif
        
        " Try to parse as JSON
        let l:json = json_decode(l:clean_chunk)
        
        if type(l:json) == v:t_dict
            if has_key(l:json, 'candidates') && len(l:json.candidates) > 0
                let l:candidate = l:json.candidates[0]
                if has_key(l:candidate, 'content') && has_key(l:candidate.content, 'parts')
                    let l:parts = l:candidate.content.parts
                    if len(l:parts) > 0 && has_key(l:parts[0], 'text')
                        return l:parts[0].text
                    endif
                endif
            endif
        endif
    catch
        call s:debug('Error processing chunk: ' . v:exception)
        if v:exception =~# 'PERMISSION_DENIED\|API key not valid'
            throw 'Invalid or missing API key. Please set g:visidian_chat_gemini_key or GEMINI_API_KEY'
        endif
        return ''
    endtry
    return ''
endfunction

" Verify API key is set and valid
function! s:verify_api_key() abort
    let l:provider = g:visidian_chat_provider
    let l:api_key = s:get_api_key()
    
    if empty(l:api_key)
        if l:provider == 'gemini'
            throw 'Gemini API key not found. Please set g:visidian_chat_gemini_key or GEMINI_API_KEY'
        else
            throw 'API key not found for provider: ' . l:provider
        endif
    endif
    
    " Verify key format
    if l:provider == 'gemini' && l:api_key !~# '^AI[a-zA-Z0-9_-]\{1,\}$'
        throw 'Invalid Gemini API key format. Key should start with "AI"'
    endif
    
    return l:api_key
endfunction

" Process streaming response
function! s:process_response(response) abort
    let l:text = ''
    for l:chunk in split(a:response, "\n")
        if empty(l:chunk)
            continue
        endif
        let l:chunk_text = s:process_chunk(l:chunk)
        if !empty(l:chunk_text)
            let l:text .= l:chunk_text
            call s:append_to_chat_buffer(l:chunk_text)
        endif
    endfor
    
    if empty(l:text)
        throw 'No valid text found in response'
    endif
    return l:text
endfunction

" Parse response based on provider
function! s:parse_response(response)
    let l:provider = g:visidian_chat_provider
    let l:json_response = json_decode(a:response)

    if l:provider == 'openai'
        return l:json_response.choices[0].message.content
    elseif l:provider == 'gemini'
        return s:process_response(a:response)
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
    try
        let l:provider = g:visidian_chat_provider
        let l:api_key = s:get_api_key()
        let l:content = "Context:\n" . a:context . "\n\nQuery:\n" . a:query
        
        if l:provider == 'openai'
            let l:endpoint = 'https://api.openai.com/v1/chat/completions'
            let l:payload = json_encode({
                \ 'model': g:visidian_chat_model[l:provider],
                \ 'messages': [
                \   {'role': 'system', 'content': 'You are a helpful assistant analyzing markdown notes.'},
                \   {'role': 'user', 'content': l:content}
                \ ]
                \})
            let l:headers = s:get_headers()
        elseif l:provider == 'gemini'
            let l:endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/' . g:visidian_chat_model[l:provider] . ':streamGenerateContent'
            let l:payload = json_encode({
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
            let l:headers = [
                \ 'Content-Type: application/json',
                \ 'x-goog-api-key: ' . l:api_key
                \ ]
        elseif l:provider == 'anthropic'
            let l:endpoint = 'https://api.anthropic.com/v1/messages'
            let l:payload = json_encode({
                \ 'model': g:visidian_chat_model[l:provider],
                \ 'messages': [{
                \   'role': 'user',
                \   'content': l:content
                \ }],
                \ 'max_tokens': 2048
                \})
            let l:headers = s:get_headers()
        elseif l:provider == 'deepseek'
            let l:endpoint = 'https://api.deepseek.com/v1/chat/completions'
            let l:payload = json_encode({
                \ 'model': g:visidian_chat_model[l:provider],
                \ 'messages': [
                \   {'role': 'system', 'content': 'You are a helpful assistant analyzing markdown notes.'},
                \   {'role': 'user', 'content': l:content}
                \ ]
                \})
            let l:headers = s:get_headers()
        endif
        
        call s:debug('Using provider: ' . l:provider)
        call s:debug('Using model: ' . g:visidian_chat_model[l:provider])
        call s:debug('Headers: ' . string(l:headers))
        
        let l:cmd = ['curl', '-s', '-X', 'POST']
        for l:header in l:headers
            call add(l:cmd, '-H')
            call add(l:cmd, l:header)
        endfor
        
        " Escape payload for shell
        let l:escaped_payload = shellescape(l:payload)
        call add(l:cmd, '-d')
        call add(l:cmd, l:escaped_payload)
        call add(l:cmd, l:endpoint)
        
        call s:debug('Making API request to: ' . l:endpoint)
        call s:debug('Provider: ' . l:provider)
        call s:debug('Payload length: ' . len(l:payload))
        call s:debug('Command: ' . string(l:cmd))
        
        let l:response = system(join(l:cmd, ' '))
        
        " Check for shell errors
        if v:shell_error
            let l:error_msg = substitute(l:response, '\^@', '', 'g')
            call s:debug('API error: ' . l:error_msg)
            throw 'API error: ' . l:error_msg
        endif
        
        " Parse response based on provider
        return s:parse_response(l:response)
    catch
        throw 'Visidian Chat Error: ' . v:exception
    endtry
endfunction

" Display a chunk of text in the chat buffer as it arrives
function! visidian#chat#display_chunk(text) abort
    let l:bufnr = bufnr('Visidian Chat')
    if l:bufnr == -1
        return
    endif
    
    " Get window number
    let l:winnr = bufwinnr(l:bufnr)
    if l:winnr == -1
        return
    endif
    
    " Save current window
    let l:cur_winnr = winnr()
    
    " Switch to chat window
    execute l:winnr . 'wincmd w'
    
    " Make buffer modifiable
    setlocal modifiable
    
    " Append text to last line
    let l:last_line = getline('$')
    if empty(l:last_line)
        call setline('$', a:text)
    else
        call setline('$', l:last_line . a:text)
    endif
    
    " Make buffer unmodifiable
    setlocal nomodifiable
    
    " Switch back to original window
    execute l:cur_winnr . 'wincmd w'
    
    " Force screen update
    redraw
endfunction

function! s:append_to_chat_buffer(text) abort
    let l:bufnr = bufnr('Visidian Chat')
    if l:bufnr == -1
        return
    endif
    
    " Get window number
    let l:winnr = bufwinnr(l:bufnr)
    if l:winnr == -1
        return
    endif
    
    " Save current window
    let l:cur_winnr = winnr()
    
    " Switch to chat window
    execute l:winnr . 'wincmd w'
    
    " Make buffer modifiable
    setlocal modifiable
    
    " Append text to last line
    call append(line('$'), a:text)
    
    " Make buffer unmodifiable
    setlocal nomodifiable
    
    " Switch back to original window
    execute l:cur_winnr . 'wincmd w'
    
    " Force screen update
    redraw
endfunction

function! visidian#chat#display_response(response) abort
    " Create or get chat buffer
    let l:bufnr = bufnr('Visidian Chat')
    if l:bufnr == -1
        " Create new buffer in vertical split
        execute 'vertical rightbelow new'
        execute 'vertical resize ' . g:visidian_chat_window_width
        setlocal buftype=nofile
        setlocal bufhidden=wipe
        setlocal noswapfile
        setlocal filetype=markdown
        setlocal wrap
        setlocal nonumber
        setlocal norelativenumber
        file Visidian Chat
        let l:bufnr = bufnr('%')
    endif
    
    " Focus the chat window
    let l:winnr = bufwinnr(l:bufnr)
    if l:winnr == -1
        " Buffer exists but window is closed, create new window
        execute 'vertical rightbelow sbuffer ' . l:bufnr
        execute 'vertical resize ' . g:visidian_chat_window_width
    else
        " Window exists, switch to it
        execute l:winnr . 'wincmd w'
    endif
    
    " Make buffer modifiable
    setlocal modifiable
    
    " Get current content
    let l:content = getline(1, '$')
    
    " Format new response
    let l:timestamp = strftime('%H:%M')
    let l:formatted_response = ['', '**[' . l:timestamp . '] Assistant:**', '']
    let l:formatted_response += split(a:response, "\n")
    
    " Add horizontal line if there's existing content
    if !empty(l:content) && l:content != ['']
        let l:formatted_response = ['---'] + l:formatted_response
    endif
    
    " Append new response to end of buffer
    call append(line('$'), l:formatted_response)
    
    " Clean up empty lines at start of buffer
    while getline(1) == '' && line('$') > 1
        1delete _
    endwhile
    
    " Move cursor to end
    normal! G
    
    " Make buffer unmodifiable again
    setlocal nomodifiable
endfunction

function! visidian#chat#send_message() abort
    try
        let l:context = visidian#chat#get_markdown_context()
        let l:query = input('Enter your query: ')
        
        if empty(l:query)
            return
        endif
        
        " Format and display user query first
        let l:timestamp = strftime('%H:%M')
        let l:user_message = ['', '**[' . l:timestamp . '] You:**', '', l:query]
        call visidian#chat#display_response(join(l:user_message, "\n"))
        
        " Process and display response
        redraw | echo "Processing..."
        let l:response = visidian#chat#send_to_llm(l:query, l:context)
        call visidian#chat#display_response(l:response)
        redraw | echo ""
    catch
        redraw | echohl ErrorMsg
        echomsg v:exception
        echohl None
        call s:debug('Unexpected error: ' . v:exception)
    endtry
endfunction

" List available models for the current provider
function! visidian#chat#list_models() abort
    try
        let l:provider = g:visidian_chat_provider
        let l:api_key = s:get_api_key()
        
        if l:provider == 'gemini'
            let l:endpoint = 'https://generativelanguage.googleapis.com/v1beta/models'
            let l:cmd = ['curl', '-s', '-X', 'GET']
            call add(l:cmd, '-H')
            call add(l:cmd, 'x-goog-api-key: ' . l:api_key)
            call add(l:cmd, shellescape(l:endpoint . '?key=' . l:api_key))
            
            call s:debug('Making API request to list models')
            let l:response = system(join(l:cmd, ' '))
            
            " Try to parse the response
            try
                let l:json_response = json_decode(l:response)
            catch
                call s:debug('JSON decode error')
                throw 'Failed to parse API response'
            endtry
            
            " Check for API errors
            if type(l:json_response) == v:t_dict && has_key(l:json_response, 'error')
                let l:error_msg = l:json_response.error.message
                call s:debug('API error: ' . l:error_msg)
                throw 'API error: ' . l:error_msg
            endif
            
            " Display available models
            if type(l:json_response) == v:t_dict && has_key(l:json_response, 'models')
                echo "Available Gemini Models:"
                for model in l:json_response.models
                    echo "- " . model.name
                endfor
            else
                throw 'Invalid response format'
            endif
        else
            throw 'Model listing not supported for provider: ' . l:provider
        endif
    catch
        echohl ErrorMsg
        echom 'Error listing models: ' . v:exception
        echohl None
        call s:debug('Error listing models: ' . v:exception)
    endtry
endfunction

" Set model for the current provider
function! visidian#chat#set_model(model_name) abort
    try
        let l:provider = g:visidian_chat_provider
        let g:visidian_chat_model[l:provider] = a:model_name
        echo "Set " . l:provider . " model to: " . a:model_name
    catch
        echohl ErrorMsg
        echom 'Error setting model: ' . v:exception
        echohl None
        call s:debug('Error setting model: ' . v:exception)
    endtry
endfunction

" Entry point for starting a chat with context
function! visidian#chat#start_chat_with_context() abort
    call s:debug('Starting chat with context')
    try
        let l:context = visidian#chat#get_markdown_context()
        call s:debug('Retrieved context: ' . len(l:context) . ' characters')
        let l:query = input("Enter your query: ")
        if !empty(l:query)
            call s:debug('Processing query: ' . l:query)
            echo "\nProcessing..."
            let l:response = visidian#chat#send_to_llm(l:query, l:context)
            call visidian#chat#display_response(l:response)
        else
            call s:debug('Empty query, aborting')
        endif
    catch /API key not set for provider:/
        let l:provider = g:visidian_chat_provider
        let l:var_name = 'g:visidian_chat_' . l:provider . '_key'
        let l:env_var = toupper(l:provider) . '_API_KEY'
        echohl ErrorMsg
        echom 'Error: API key not set for ' . l:provider
        echom 'Please set either ' . l:var_name . ' in your vimrc or the ' . l:env_var . ' environment variable'
        echohl None
        call s:debug('API key missing for provider: ' . l:provider)
    catch
        echohl ErrorMsg
        echom 'Error: ' . v:exception
        echohl None
        call s:debug('Unexpected error: ' . v:exception)
    endtry
endfunction

" Map a key to open the chat window
if !hasmapto('<Plug>VisidianChatOpen')
    " Remove the default mapping to avoid conflicts
    " Users can set their own mapping in their vimrc
endif
nnoremap <unique> <Plug>VisidianChatOpen :call visidian#chat#create_window()<CR>