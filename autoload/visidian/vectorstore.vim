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
    let l:store_path = expand(g:visidian_vectorstore_path)
    if !isdirectory(l:store_path)
        call mkdir(l:store_path, 'p')
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
        call s:debug('Provider: ' . l:provider)
        call s:debug('Text length: ' . len(a:text))
        
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
            let l:model = exists('g:visidian_chat_gemini_model') ? g:visidian_chat_gemini_model : 'embedding-001'
            let l:endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/' . l:model . ':embedContent?key=' . l:api_key
            let l:payload = json_encode({
                \ 'model': l:model,
                \ 'content': {
                \   'parts': [
                \     { 'text': a:text }
                \   ]
                \ }
                \ })
            let l:headers = [
                \ 'Content-Type: application/json'
                \ ]
        endif
        
        call s:debug('Payload: ' . l:payload)
        let l:cmd = ['curl', '-s', '-X', 'POST']
        for l:header in l:headers
            call add(l:cmd, '-H')
            call add(l:cmd, l:header)
        endfor
        
        " Escape payload for shell
        let l:escaped_payload = shellescape(l:payload)
        call extend(l:cmd, ['-d', l:escaped_payload, shellescape(l:endpoint)])
        
        call s:debug('Making API request to: ' . l:endpoint)
        let l:response = system(join(l:cmd, ' '))
        call s:debug('API response length: ' . len(l:response))
        if v:shell_error
            let l:error_msg = substitute(l:response, '\^@', '', 'g')
            call s:debug('API error: ' . l:error_msg)
            throw 'API error: ' . l:error_msg
        endif

        " Parse response
        let l:json_response = json_decode(l:response)
        call s:debug('Parsed JSON response')
        
        " Check for API errors
        if type(l:json_response) == v:t_dict && has_key(l:json_response, 'error')
            let l:error_msg = l:json_response.error.message
            call s:debug('API error: ' . l:error_msg)
            throw 'API error: ' . l:error_msg
        endif

        if l:provider == 'gemini'
            if type(l:json_response) == v:t_dict && has_key(l:json_response, 'embedding')
                return l:json_response.embedding.values
            endif
            throw 'No embedding found in response'
        elseif l:provider == 'openai'
            if type(l:json_response) == v:t_dict && has_key(l:json_response, 'data') && len(l:json_response.data) > 0
                return l:json_response.data[0].embedding
            endif
            throw 'No embedding found in response'
        endif
        
        throw 'Invalid provider: ' . l:provider
    catch /API key not set for provider:/
        throw v:exception
    catch
        call s:debug('Error in get_embeddings: ' . v:exception)
        throw v:exception
    endtry
endfunction

" Get safe filename for storing embeddings
function! s:get_store_filename(file_path) abort
    " Convert absolute path to safe filename
    let l:safe_name = substitute(a:file_path, '[^A-Za-z0-9._-]', '_', 'g')
    let l:safe_name = substitute(l:safe_name, '__\+', '_', 'g')  " Collapse multiple underscores
    let l:safe_name = substitute(l:safe_name, '^_\|_$', '', 'g') " Remove leading/trailing underscores
    return expand(g:visidian_vectorstore_path) . '/' . l:safe_name . '.json'
endfunction

" Store embeddings for a note
function! visidian#vectorstore#store_note(file_path) abort
    " Ensure store directory exists
    call visidian#vectorstore#init()
    
    " Read file content
    let l:content = join(readfile(a:file_path, 'b'), "\n")  " Ensure binary read
    call s:debug('Read file content of length: ' . len(l:content))
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
    let l:store_file = s:get_store_filename(a:file_path)
    call writefile([json_encode(l:metadata)], l:store_file, 'b')  " Ensure binary write
    call s:debug('Stored metadata in: ' . l:store_file)
endfunction

" Find relevant notes using cosine similarity
function! visidian#vectorstore#find_relevant_notes(query, max_results) abort
    let l:query_embedding = s:get_embeddings(a:query)
    let l:results = []
    let l:store_path = expand(g:visidian_vectorstore_path)
    
    " Search through all stored embeddings
    for l:file in glob(l:store_path . '/*.json', 0, 1)
        if filereadable(l:file)
            try
                let l:metadata = json_decode(join(readfile(l:file, 'b'), "\n"))  " Ensure binary read
                for l:chunk in l:metadata
                    let l:similarity = s:cosine_similarity(l:query_embedding, l:chunk.embedding)
                    call add(l:results, {
                        \ 'similarity': l:similarity,
                        \ 'chunk': l:chunk.chunk,
                        \ 'file_path': l:chunk.file_path
                        \ })
                endfor
            catch
                call s:debug('Error reading file: ' . l:file . ' - ' . v:exception)
                continue
            endtry
        endif
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
