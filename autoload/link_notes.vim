" Check if YAML parser is available
function! s:yaml_parser_available()
    return exists('*yaml#decode')
endfunction

function! visidian#link_notes#link_notes()
    if g:visidian_vault_path == ''
        echoerr "No vault path set. Please create or set a vault first."
        return
    endif

    let current_file = expand('%:p')
    let current_yaml = s:get_yaml_front_matter(current_file)
    if empty(current_yaml)
        echo "No YAML front matter found in the current file."
        return
    endif

    let links = get(current_yaml, 'links', [])
    let tags = get(current_yaml, 'tags', [])

    call s:search_and_link(links, tags)
endfunction

" Parse YAML front matter
function! s:get_yaml_front_matter(file)
    let lines = readfile(a:file)
    let yaml_start = match(lines, '^---$')
    if yaml_start == -1
        return {}
    endif
    let yaml_end = match(lines, '^---$', yaml_start + 1)
    if yaml_end == -1
        return {}
    endif
    let yaml_content = join(lines[yaml_start+1 : yaml_end-1], "\n")

    if s:yaml_parser_available()
        return yaml#decode(yaml_content)
    else
        " Fallback to simple parsing for tags and links
        let yaml_dict = {}
        for line in split(yaml_content, '\n')
            let match = matchlist(line, '\v^(\w+):\s*(.*)')
            if !empty(match)
                let key = match[1]
                let value = match[2]
                if key == 'tags' || key == 'links'
                    let yaml_dict[key] = map(split(value, '\s*,\s*'), 'trim(v:val)')
                else
                    let yaml_dict[key] = value
                endif
            endif
        endfor
        return yaml_dict
    endif
endfunction

" Search and link notes
function! s:search_and_link(links, tags)
    let vault_files = globpath(g:visidian_vault_path, '**/*.md', 0, 1)
    let linked_notes = {}

    for file in vault_files
        let file_yaml = s:get_yaml_front_matter(file)
        if !empty(file_yaml)
            let file_links = get(file_yaml, 'links', [])
            let file_tags = get(file_yaml, 'tags', [])

            " Check for matching tags
            for tag in a:tags
                if index(file_tags, tag) != -1
                    let linked_notes[file] = 'Tag match: ' . tag
                endif
            endfor

            " Check for direct links
            if !empty(a:links) && index(file_links, fnamemodify(expand('%'), ':t')) != -1
                let linked_notes[file] = 'Direct link'
            endif
        endif
    endfor

    if !empty(linked_notes)
        enew
        setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap

        call append(0, 'Linked Notes:')
        for [file, reason] in items(linked_notes)
            call append(line('$'), substitute(file, g:visidian_vault_path, '', '') . ' - ' . reason)
        endfor
        normal! gg
    else
        echo "No links or tag matches found."
    endif
endfunction
