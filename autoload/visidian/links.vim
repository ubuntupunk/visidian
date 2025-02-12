" visidian/autoload/links.vim - Link management functions

" Function: visidian#links#parse_yaml_links
" Description: Extract links from YAML frontmatter
" Parameters:
"   - content: List of lines containing YAML frontmatter
" Returns: List of link targets found in YAML
function! visidian#links#parse_yaml_links(content) abort
    let links = []
    let in_yaml = 0
    let yaml_end = 0
    
    " Find YAML frontmatter boundaries
    for i in range(len(a:content))
        let line = a:content[i]
        
        " Check for YAML start/end markers
        if i == 0 && line =~# '^---\s*$'
            let in_yaml = 1
            continue
        elseif in_yaml && line =~# '^---\s*$'
            let yaml_end = i
            break
        endif
        
        if in_yaml
            " Look for link fields in YAML
            let link_match = matchlist(line, '^\s*\(links\|related\|references\):\s*\[\?\s*\(.*\)')
            if !empty(link_match)
                " Handle array format
                if line =~# '\[\s*.*\s*\]'
                    " Extract links from array format: links: [link1, link2]
                    let items = split(link_match[2], ',\s*')
                    for item in items
                        let clean_item = substitute(item, '[\[\]]', '', 'g')
                        if !empty(clean_item)
                            call add(links, clean_item)
                        endif
                    endfor
                else
                    " Handle multi-line array format
                    let j = i + 1
                    while j < len(a:content) && a:content[j] =~# '^\s*-\s'
                        let item = matchstr(a:content[j], '^\s*-\s*\zs.*\ze\s*$')
                        if !empty(item)
                            call add(links, item)
                        endif
                        let j += 1
                    endwhile
                endif
            endif
        endif
    endfor
    
    return links
endfunction

" Function: visidian#links#get_links_in_file
" Description: Get all markdown links from a file
" Parameters:
"   - file_path: Full path to the file to analyze
" Returns: List of dictionaries with link information
function! visidian#links#get_links_in_file(file_path) abort
    let links = []
    
    " Read file content
    let content = readfile(a:file_path)
    
    " Get YAML frontmatter links
    let yaml_links = visidian#links#parse_yaml_links(content)
    for link in yaml_links
        call add(links, {'type': 'yaml', 'target': link, 'line': ''})
    endfor
    
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

" Function: visidian#links#update_yaml_links
" Description: Update or create YAML frontmatter links
" Parameters:
"   - file_path: Path to the file to update
"   - new_links: List of links to add/update
" Returns: 1 if successful, 0 if failed
function! visidian#links#update_yaml_links(file_path, new_links) abort
    let content = readfile(a:file_path)
    let has_yaml = 0
    let yaml_start = -1
    let yaml_end = -1
    let links_line = -1
    
    " Find existing YAML frontmatter
    for i in range(len(content))
        if i == 0 && content[i] =~# '^---\s*$'
            let has_yaml = 1
            let yaml_start = i
        elseif has_yaml && content[i] =~# '^---\s*$'
            let yaml_end = i
            break
        elseif has_yaml && content[i] =~# '^\s*links:'
            let links_line = i
        endif
    endfor
    
    " Create new YAML content
    if empty(a:new_links)
        return 1
    endif
    
    let links_content = ['links:']
    for link in a:new_links
        call add(links_content, '  - ' . link)
    endfor
    
    " Update or create YAML section
    if has_yaml
        if links_line != -1
            " Replace existing links section
            let delete_end = links_line + 1
            while delete_end < yaml_end && content[delete_end] =~# '^\s\+-\s'
                let delete_end += 1
            endwhile
            let content = content[:links_line-1] + links_content + content[delete_end:]
        else
            " Add links section before YAML end
            let content = content[:yaml_end-1] + links_content + content[yaml_end:]
        endif
    else
        " Create new YAML frontmatter
        let content = ['---'] + links_content + ['---'] + content
    endif
    
    " Write back to file
    try
        call writefile(content, a:file_path)
        return 1
    catch
        call visidian#debug#error('LINKS', 'Failed to update YAML links: ' . v:exception)
        return 0
    endtry
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
"   - type: Type of link to create ('wiki', 'markdown', or 'yaml')
" Returns: The created link text
function! visidian#links#create_link(target, type) abort
    let filename = fnamemodify(a:target, ':t:r')
    
    if a:type ==# 'wiki'
        return '[[' . filename . ']]'
    elseif a:type ==# 'markdown'
        return '[' . filename . '](' . filename . '.md)'
    elseif a:type ==# 'yaml'
        return filename
    else
        throw 'Invalid link type: ' . a:type
    endif
endfunction
