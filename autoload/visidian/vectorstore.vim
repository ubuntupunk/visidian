" Visidian Vector Store
" Maintainer: ubuntupunk
" License: GPL3

" Configuration
if !exists('g:visidian_vectorstore_provider')
    let g:visidian_vectorstore_provider = 'openai'  " Options: 'openai', 'gemini'
endif

if !exists('g:visidian_vectorstore_path')
    let g:visidian_vectorstore_path = expand('~/.cache/visidian/vectorstore')
endif

if !exists('g:visidian_max_context_tokens')
    let g:visidian_max_context_tokens = 4000
endif

" Initialize vector store directory
function! visidian#vectorstore#init() abort
    if !isdirectory(g:visidian_vectorstore_path)
        call mkdir(g:visidian_vectorstore_path, 'p')
    endif
endfunction

" Get embeddings for text using selected provider
function! s:get_embeddings(text) abort
    let l:provider = g:visidian_vectorstore_provider
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
        let l:endpoint = 'https://generativelanguage.googleapis.com/v1/models/embedding-001:embedText'
        let l:payload = json_encode({
            \ 'text': a:text
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
    call extend(l:cmd, ['-d', l:payload, l:endpoint])
    
    let l:response = system(join(l:cmd, ' '))
    return s:parse_embedding_response(l:response)
endfunction

" Parse embedding response based on provider
function! s:parse_embedding_response(response) abort
    let l:json_response = json_decode(a:response)
    let l:provider = g:visidian_vectorstore_provider
    
    if l:provider == 'openai'
        return l:json_response.data[0].embedding
    elseif l:provider == 'gemini'
        return l:json_response.embedding.values
    endif
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
