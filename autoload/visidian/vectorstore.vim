" Visidian Vector Store
" Maintainer: ubuntupunk
" License: GPL3

" Configuration
if !exists('g:visidian_vectorstore_provider')
    let g:visidian_vectorstore_provider = 'gemini'  " Options: 'openai', 'gemini'
endif

if !exists('g:visidian_vectorstore_path')
    let g:visidian_vectorstore_path = expand('~/.cache/visidian/vectorstore')
endif

if !exists('g:visidian_max_context_tokens')
    let g:visidian_max_context_tokens = 4000
endif

" Debug logging helper
function! s:debug(msg) abort
    if exists('g:visidian_debug') && g:visidian_debug
        echom '[VECTORSTORE] ' . a:msg
    endif
endfunction

" Initialize vector store directory
function! visidian#vectorstore#init() abort
    if !isdirectory(g:visidian_vectorstore_path)
        call mkdir(g:visidian_vectorstore_path, 'p')
    endif
endfunction

" Get API key based on provider
function! s:get_provider_key(provider) abort
    if a:provider == 'openai'
        let l:key = g:visidian_chat_openai_key
        if empty(l:key)
            call s:debug('OpenAI API key not found in g:visidian_chat_openai_key or $OPENAI_API_KEY')
            throw 'API key not set for provider: openai'
        endif
        return l:key
    elseif a:provider == 'gemini'
        let l:key = g:visidian_chat_gemini_key
        if empty(l:key)
            call s:debug('Gemini API key not found in g:visidian_chat_gemini_key or $GEMINI_API_KEY')
            throw 'API key not set for provider: gemini'
        endif
        return l:key
    endif
    call s:debug('Invalid provider requested: ' . a:provider)
    throw 'Invalid provider: ' . a:provider
endfunction

" Get embeddings for text using selected provider
function! s:get_embeddings(text) abort
    let l:provider = g:visidian_vectorstore_provider
    
    try
        let l:api_key = s:get_provider_key(l:provider)
        
        if l:provider == 'openai'
            let l:endpoint = 'https://api.openai.com/v1/embeddings'
            let l:payload = json_encode({
                \ 'model': 'text-embedding-3-small',
                \ 'input': a:text
                \ })
            let l:headers = [
                \ 'Content-Type: application/json',
                \ 'Authorization: Bearer ' . l:api_key
                \ ]
        elseif l:provider == 'gemini'
            let l:model = exists('g:visidian_chat_gemini_model') ? g:visidian_chat_gemini_model : 'gemini-1.0-pro'
            let l:endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/' . l:model . ':embedContent'
            let l:payload = json_encode({
                \ 'model': 'models/' . l:model,
                \ 'content': {
                \   'parts': [
                \     { 'text': a:text }
                \   ]
                \ }
                \ })
            let l:headers = [
                \ 'Content-Type: application/json',
                \ 'x-goog-api-key: ' . l:api_key
                \ ]
        endif
        
        let l:cmd = ['curl', '-s', '-X', 'POST']
        for l:header in l:headers
            call add(l:cmd, '-H')
            call add(l:cmd, l:header)
        endfor
        
        " Escape payload for shell
        let l:escaped_payload = shellescape(l:payload)
        call extend(l:cmd, ['-d', l:escaped_payload, shellescape(l:endpoint)])
        
        call s:debug('Making API request')
        call s:debug('Provider: ' . l:provider)
        call s:debug('Payload length: ' . len(l:payload))
        
        let l:response = system(join(l:cmd, ' '))
        let l:json_response = json_decode(l:response)
        
        " Check for API errors
        if type(l:json_response) == v:t_dict && has_key(l:json_response, 'error')
            let l:error_msg = l:json_response.error.message
            call s:debug('API error: ' . l:error_msg)
            throw 'API error: ' . l:error_msg
        endif
        
        call s:debug('API Response received')
        
        if v:shell_error
            call s:debug('API request failed')
            throw 'API request failed'
        endif
        
        return s:parse_embedding_response(l:response)
    catch /API key not set for provider:/
        throw v:exception
    catch
        call s:debug('Error in get_embeddings: ' . v:exception)
        throw v:exception
    endtry
endfunction

" Parse the embedding response based on the provider
function! s:parse_embedding_response(response) abort
    let l:provider = g:visidian_vectorstore_provider
    let l:json_response = json_decode(a:response)
        call s:debug('Parsed JSON response type: ' . type(l:json_response))
    
    if l:provider == 'openai'
            if type(l:json_response) == v:t_dict && has_key(l:json_response, 'data') && len(l:json_response.data) > 0
                call s:debug('Successfully parsed OpenAI embedding response')
        return l:json_response.data[0].embedding
            endif
            call s:debug('Invalid OpenAI API response: ' . a:response)
            throw 'Invalid OpenAI API response: ' . a:response
    elseif l:provider == 'gemini'
            if type(l:json_response) == v:t_dict && has_key(l:json_response, 'embedding')
                call s:debug('Successfully parsed Gemini embedding response')
                return l:json_response.embedding
    endif
            call s:debug('Invalid Gemini API response: ' . a:response)
            throw 'Invalid Gemini API response: ' . a:response
        endif
    throw 'Invalid provider: ' . l:provider
    catch
        let l:error_msg = 'Error parsing embedding response: ' . v:exception
        call s:debug(l:error_msg)
        call s:debug('Raw response: ' . a:response)
        echohl ErrorMsg
        echom l:error_msg
        echohl None
        return []
    endtry
endfunction

" Store embeddings for a note
function! visidian#vectorstore#store_note(file_path) abort
    let l:content = join(readfile(a:file_path), "\n")
    let l:chunks = s:chunk_text(l:content, 1000)  " Split into ~1000 token chunks
    let l:metadata = []
    
    for l:chunk in l:chunks
        let l:embedding = s:get_embeddings(l:chunk)
        call add(l:metadata, {
            \ 'chunk': l:chunk,
            \ 'embedding': l:embedding,
            \ 'file_path': a:file_path
            \ })
    endfor
    
    " Store metadata as JSON
    let l:store_file = g:visidian_vectorstore_path . '/' . substitute(a:file_path, '/', '_', 'g') . '.json'
    call writefile([json_encode(l:metadata)], l:store_file)
endfunction

" Find relevant notes using cosine similarity
function! visidian#vectorstore#find_relevant_notes(query, max_results) abort
    let l:query_embedding = s:get_embeddings(a:query)
    let l:results = []
    
    " Search through all stored embeddings
    for l:file in glob(g:visidian_vectorstore_path . '/*.json', 0, 1)
        let l:metadata = json_decode(join(readfile(l:file), "\n"))
        for l:chunk in l:metadata
            let l:similarity = s:cosine_similarity(l:query_embedding, l:chunk.embedding)
            call add(l:results, {
                \ 'similarity': l:similarity,
                \ 'chunk': l:chunk.chunk,
                \ 'file_path': l:chunk.file_path
                \ })
        endfor
    endfor
    
    " Sort by similarity and return top results
    call sort(l:results, {a, b -> a.similarity < b.similarity ? 1 : -1})
    return l:results[0:a:max_results-1]
endfunction

" Calculate cosine similarity between two vectors
function! s:cosine_similarity(vec1, vec2) abort
    let l:dot_product = 0.0
    let l:norm1 = 0.0
    let l:norm2 = 0.0
    
    for i in range(len(a:vec1))
        let l:dot_product += a:vec1[i] * a:vec2[i]
        let l:norm1 += a:vec1[i] * a:vec1[i]
        let l:norm2 += a:vec2[i] * a:vec2[i]
    endfor
    
    return l:dot_product / (sqrt(l:norm1) * sqrt(l:norm2))
endfunction

" Split text into chunks of approximately max_tokens
function! s:chunk_text(text, max_tokens) abort
    let l:chunks = []
    let l:lines = split(a:text, "\n")
    let l:current_chunk = []
    let l:current_tokens = 0
    
    for l:line in l:lines
        let l:line_tokens = len(split(l:line, '\W\+'))
        if l:current_tokens + l:line_tokens > a:max_tokens && len(l:current_chunk) > 0
            call add(l:chunks, join(l:current_chunk, "\n"))
            let l:current_chunk = []
            let l:current_tokens = 0
        endif
        call add(l:current_chunk, l:line)
        let l:current_tokens += l:line_tokens
    endfor
    
    if len(l:current_chunk) > 0
        call add(l:chunks, join(l:current_chunk, "\n"))
    endif
    
    return l:chunks
endfunction
