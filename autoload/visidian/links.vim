" visidian/autoload/links.vim - Link management functions

" Function: visidian#links#yaml_parser_available
" Description: Check if yaml parser is available
function! visidian#links#yaml_parser_available()
    return exists('*yaml#decode')
endfunction

" Function: visidian#links#parse_simple_yaml
" Description: Simple YAML parser fallback
function! visidian#links#parse_simple_yaml(text)
    let yaml = {'tags': [], 'links': []}
    let lines = split(a:text, "\n")
    
    for line in lines
        " Skip empty lines and comments
        if line =~ '^\s*$' || line =~ '^\s*#'
            continue
        endif
        
        " Match key: value or key: [value1, value2]
        let matches = matchlist(line, '^\s*\(\w\+\):\s*\(\[.\{-}\]\|\S.\{-}\)\s*$')
        if !empty(matches)
            let key = matches[1]
            let value = matches[2]
            
            " Handle arrays
            if value =~ '^\['
                let value = split(substitute(value[1:-2], '\s', '', 'g'), ',')
            endif
            
            let yaml[key] = value
        endif
    endfor
    
    return yaml
endfunction

" Function: visidian#links#get_yaml_front_matter
" Description: Get YAML front matter with fallback parser
function! visidian#links#get_yaml_front_matter(file)
    call visidian#debug#debug('LINKS', 'Reading YAML from: ' . a:file)

    try
        let lines = readfile(a:file)
        let yaml_text = []
        let in_yaml = 0
        let yaml_end = 0
        
        " Check if file starts with YAML frontmatter
        if len(lines) > 0 && lines[0] =~ '^---\s*$'
            let in_yaml = 1
            for line in lines[1:]
                if line =~ '^---\s*$'
                    let yaml_end = 1
                    break
                endif
                call add(yaml_text, line)
            endfor
        endif
        
        " Return empty YAML if no frontmatter found
        if !yaml_end
            return {'tags': [], 'links': []}
        endif
        
        let yaml_str = join(yaml_text, "\n")
        let yaml = {}
        
        " Try using yaml#decode if available
        if visidian#links#yaml_parser_available()
            try
                let yaml = yaml#decode(yaml_str)
            catch
                " Silently fall back to simple parser
                let yaml = {}
            endtry
        endif
        
        " If yaml#decode failed or wasn't available, use simple parser
        if empty(yaml)
            let yaml = visidian#links#parse_simple_yaml(yaml_str)
        endif
        
        " Ensure required fields exist
        let yaml.tags = get(yaml, 'tags', [])
        let yaml.links = get(yaml, 'links', [])
        
        return yaml
    catch
        return {'tags': [], 'links': []}
    endtry
endfunction

" Function: visidian#links#parse_yaml_links
" Description: Extract links from YAML frontmatter
" Parameters:
"   - content: List of lines containing YAML frontmatter
" Returns: List of link targets found in YAML
function! visidian#links#parse_yaml_links(content) abort
    call visidian#debug#debug('LINKS', 'Parsing YAML frontmatter for links')
    let links = []
    let in_yaml = 0
    let yaml_end = 0
    
    " Find YAML frontmatter boundaries
    for i in range(len(a:content))
        let line = a:content[i]
        
        " Check for YAML start/end markers
        if i == 0 && line =~# '^---\s*$'
            call visidian#debug#debug('LINKS', 'Found YAML start marker')
            let in_yaml = 1
            continue
        elseif in_yaml && line =~# '^---\s*$'
            call visidian#debug#debug('LINKS', 'Found YAML end marker at line ' . i)
            let yaml_end = i
            break
        endif
        
        if in_yaml
            " Look for link fields in YAML
            let link_match = matchlist(line, '^\s*\(links\|related\|references\):\s*\[\?\s*\(.*\)')
            if !empty(link_match)
                call visidian#debug#debug('LINKS', 'Found link field: ' . link_match[1])
                " Handle array format
                if line =~# '\[\s*.*\s*\]'
                    " Extract links from array format: links: [link1, link2]
                    let items = split(link_match[2], ',\s*')
                    for item in items
                        let clean_item = substitute(item, '[\[\]]', '', 'g')
                        if !empty(clean_item)
                            call add(links, clean_item)
                            call visidian#debug#debug('LINKS', 'Added inline array link: ' . clean_item)
                        endif
                    endfor
                else
                    " Handle multi-line array format
                    let j = i + 1
                    while j < len(a:content) && a:content[j] =~# '^\s*-\s'
                        let item = matchstr(a:content[j], '^\s*-\s*\zs.*\ze\s*$')
                        if !empty(item)
                            call add(links, item)
                            call visidian#debug#debug('LINKS', 'Added multi-line link: ' . item)
                        endif
                        let j += 1
                    endwhile
                endif
            endif
        endif
    endfor
    
    call visidian#debug#debug('LINKS', 'Found ' . len(links) . ' links in YAML frontmatter')
    return links
endfunction

" Function: visidian#links#get_links_in_file
" Description: Get all markdown links from a file
" Parameters:
"   - file_path: Full path to the file to analyze
" Returns: List of dictionaries with link information
function! visidian#links#get_links_in_file(file_path) abort
    call visidian#debug#debug('LINKS', 'Getting links from file: ' . a:file_path)
    let links = []
    
    " Read file content
    if !filereadable(a:file_path)
        call visidian#debug#error('LINKS', 'Cannot read file: ' . a:file_path)
        return []
    endif
    
    let content = readfile(a:file_path)
    call visidian#debug#debug('LINKS', 'Read ' . len(content) . ' lines from file')
    
    " Get YAML frontmatter links
    let yaml = visidian#links#get_yaml_front_matter(a:file_path)
    for link in yaml.links
        call add(links, {'type': 'yaml', 'target': link, 'line': ''})
        call visidian#debug#debug('LINKS', 'Added YAML link: ' . link)
    endfor
    
    " Regular expressions for different link types
    let wiki_link_pattern = '\[\[\([^\]]\+\)\]\]'                    " [[link]]
    let md_link_pattern = '\[.\{-}\](\([^)]\+\))'                   " [text](link)
    let bare_link_pattern = '<\?\(https\?://[^ >]\+\)>\?'           " http(s)://...
    
    let wiki_count = 0
    let md_count = 0
    let url_count = 0
    
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
                let wiki_count += 1
                call visidian#debug#debug('LINKS', 'Found wiki link: ' . target)
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
                let md_count += 1
                call visidian#debug#debug('LINKS', 'Found markdown link: ' . link[1])
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
                let url_count += 1
                call visidian#debug#debug('LINKS', 'Found URL link: ' . link[1])
            endif
            let start = match[2]
        endwhile
    endfor

    call visidian#debug#info('LINKS', printf('Found %d links (%d wiki, %d markdown, %d URL, %d YAML)',
        \ len(links), wiki_count, md_count, url_count, len(yaml.links)))
    return links
endfunction

" Function: visidian#links#create_link
" Description: Create a link of specified type
" Parameters:
"   - target: Link target (file path or URL)
"   - type: Link type (wiki, markdown, url)
" Returns: Formatted link string
function! visidian#links#create_link(target, type) abort
    call visidian#debug#debug('LINKS', 'Creating ' . a:type . ' link to: ' . a:target)
    
    if a:type ==# 'wiki'
        return '[[' . a:target . ']]'
    elseif a:type ==# 'markdown'
        let title = fnamemodify(a:target, ':t:r')
        return '[' . title . '](' . a:target . ')'
    elseif a:type ==# 'url'
        return '<' . a:target . '>'
    endif
    
    return a:target
endfunction

" Function: visidian#links#parse_link
" Description: Parse and normalize a link
" Parameters:
"   - link: Link string to parse
" Returns: Dictionary with link information
function! visidian#links#parse_link(link)
    let link = a:link
    let type = 'internal'
    
    " Handle quoted links
    if link =~ '^".*"$' || link =~ "^'.*'$"
        let link = link[1:-2]
    endif
    
    " Handle external links
    if link =~ '^https\?://'
        let type = 'external'
        return {'type': type, 'path': link, 'display': link}
    endif
    
    " Handle expanded vault paths
    if link =~ '^\$VAULT_PATH:'
        let expanded = substitute(link, '^\$VAULT_PATH:', g:visidian_vault_path, '')
        return {'type': 'internal', 'path': expanded, 'display': link}
    endif
    
    " Handle relative paths
    if link =~ '^\.\./' || link =~ '^\./'
        return {'type': 'internal', 'path': link, 'display': fnamemodify(link, ':t:r')}
    endif
    
    " Default to internal
    return {'type': 'internal', 'path': link, 'display': link}
endfunction
