" visidian/autoload/links.vim - Link management functions

" Function: visidian#links#get_links_in_file
" Description: Get all markdown links from a file
" Parameters:
"   - file_path: Full path to the file to analyze
" Returns: List of dictionaries with link information
function! visidian#links#get_links_in_file(file_path) abort
    let links = []
    
    " Read file content
    let content = readfile(a:file_path)
    
    " Regular expressions for different link types
    let wiki_link_pattern = '\[\[\([^\]]\+\)\]\]'                    " [[link]]
    let md_link_pattern = '\[.\{-}\](\([^)]\+\))'                   " [text](link)
    let bare_link_pattern = '<\?\(https\?://[^ >]\+\)>\?'           " http(s)://...
    
    for line in content
        " Find wiki-style links [[link]]
        let start = 0
        while 1
            let match = matchstrpos(line, wiki_link_pattern, start)
            if match[1] == -1
                break
            endif
            let link = matchlist(line, wiki_link_pattern, match[1])
            if !empty(link)
                let target = link[1]
                " Handle links with display text: [[target|text]]
                let parts = split(target, '|')
                if len(parts) > 1
                    let target = parts[0]
                endif
                call add(links, {'type': 'wiki', 'target': target, 'line': line})
            endif
            let start = match[2]
        endwhile

        " Find markdown links [text](link)
        let start = 0
        while 1
            let match = matchstrpos(line, md_link_pattern, start)
            if match[1] == -1
                break
            endif
            let link = matchlist(line, md_link_pattern, match[1])
            if !empty(link)
                call add(links, {'type': 'markdown', 'target': link[1], 'line': line})
            endif
            let start = match[2]
        endwhile

        " Find bare URLs
        let start = 0
        while 1
            let match = matchstrpos(line, bare_link_pattern, start)
            if match[1] == -1
                break
            endif
            let link = matchlist(line, bare_link_pattern, match[1])
            if !empty(link)
                call add(links, {'type': 'url', 'target': link[1], 'line': line})
            endif
            let start = match[2]
        endwhile
    endfor

    return links
endfunction

" Function: visidian#links#get_backlinks
" Description: Find all files that link to the given file
" Parameters:
"   - target_file: Filename to find backlinks for
" Returns: List of dictionaries with backlink information
function! visidian#links#get_backlinks(target_file) abort
    let backlinks = []
    let vault_path = g:visidian_vault_path
    
    " Get all markdown files in the vault
    let files = globpath(vault_path, '**/*.md', 0, 1)
    
    " Remove .md extension from target for matching
    let target_base = fnamemodify(a:target_file, ':r')
    
    for file in files
        " Skip the target file itself
        if fnamemodify(file, ':t') ==# a:target_file
            continue
        endif
        
        " Get links from the current file
        let links = visidian#links#get_links_in_file(file)
        
        " Check if any links point to our target
        for link in links
            let link_target = fnamemodify(link.target, ':r')
            if link_target ==# target_base
                call add(backlinks, {
                    \ 'source': file,
                    \ 'type': link.type,
                    \ 'line': link.line
                    \ })
            endif
        endfor
    endfor
    
    return backlinks
endfunction

" Function: visidian#links#create_link
" Description: Create a link to another note
" Parameters:
"   - target: Target file to link to
"   - type: Type of link to create ('wiki' or 'markdown')
" Returns: The created link text
function! visidian#links#create_link(target, type) abort
    let filename = fnamemodify(a:target, ':t:r')
    
    if a:type ==# 'wiki'
        return '[[' . filename . ']]'
    elseif a:type ==# 'markdown'
        return '[' . filename . '](' . filename . '.md)'
    else
        throw 'Invalid link type: ' . a:type
    endif
endfunction
