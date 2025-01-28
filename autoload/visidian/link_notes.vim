"autoload/visidian/link_notes.vim

" FUNCTION: Check if YAML parser is available
function! s:yaml_parser_available()
    return exists('*yaml#decode')
endfunction

"FUNCTION: Link Notes
function! visidian#link_notes#link_notes()
    " Check if vault exists
    if empty(g:visidian_vault_path)
        echohl ErrorMsg
        echo "No vault path set. Please create or set a vault first."
        echohl None
        return 0
    endif

    " Normalize vault path
    let vault_path = substitute(g:visidian_vault_path, '[\/]\+$', '', '')

    " Get all markdown files in the vault
    let vault_files = []
    for para_folder in ['Projects', 'Areas', 'Resources', 'Archive']
        let folder_path = vault_path . '/' . para_folder
        if isdirectory(folder_path)
            " Get all markdown files in this folder and its subfolders
            let folder_files = glob(folder_path . '/**/*.md', 0, 1)
            let vault_files += folder_files
        endif
    endfor

    if empty(vault_files)
        echohl WarningMsg
        echo "No markdown files found in vault."
        echohl None
        return 0
    endif

    " Get current file path
    let current_file = expand('%:p')
    if current_file !~# '\.md$'
        echohl ErrorMsg
        echo "Current file is not a markdown file."
        echohl None
        return 0
    endif

    " Remove current file from the list if it exists
    let vault_files = filter(vault_files, 'v:val !=# current_file')

    if empty(vault_files)
        echohl WarningMsg
        echo "No other markdown files found to link to."
        echohl None
        return 0
    endif

    " Get YAML front matter from current file
    let current_yaml = s:get_yaml_front_matter(current_file)
    if empty(current_yaml)
        echo "No YAML front matter found in the current file."
        return
    endif

    let links = get(current_yaml, 'links', [])
    let tags = get(current_yaml, 'tags', [])

    call s:search_and_link(links, tags)

    let weighted_links = s:weight_and_sort_links(current_yaml, vault_files)

    if !empty(weighted_links)
        enew
        setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap

        call append(0, 'Linked Notes:')
    for [file, score] in items(weighted_links)
        " Get relative path from vault root
        let rel_path = substitute(file, escape(vault_path . '/', '/\'), '', '')
        " Add number prefix, score, and make it look nice
        call add(display_files, printf('%2d) %-50s [Score: %d]', i, rel_path, score))
        let i += 1
    endfor

    " If no weighted links, show all files
    if empty(display_files)
        let i = 1
        for file in vault_files
            let rel_path = substitute(file, escape(vault_path . '/', '/\'), '', '')
            call add(display_files, printf('%2d) %s', i, rel_path))
            let i += 1
        endfor
    endif

    " Show file list
    echo "Select file to link to:\n"
    echo join(display_files, "\n")
    
    " Get user choice
    let choice = input("\nEnter number (1-" . len(display_files) . "): ")
    if empty(choice) || choice < 1 || choice > len(display_files)
        echo "\nInvalid choice. Cancelled."
        return 0
    endif

    " Get selected file
    let target_file = !empty(weighted_links) ? keys(weighted_links)[choice - 1] : vault_files[choice - 1]
    
    " Create the link
    let link_text = fnamemodify(target_file, ':t:r')  " Get filename without extension
    let rel_path = substitute(target_file, escape(vault_path . '/', '/\'), '', '')
    let link = '[[' . rel_path . '|' . link_text . ']]'
    
    " Insert the link at cursor position
    let pos = getpos('.')
    let line = getline('.')
    let new_line = strpart(line, 0, pos[2]-1) . link . strpart(line, pos[2]-1)
    call setline('.', new_line)
    
    " Move cursor to end of inserted link
    let pos[2] += len(link)
    call setpos('.', pos)
    
    echo "\nLinked to: " . rel_path
    return 1
endfunction

"FUNCTION: Weight and Sort Links
function! s:weight_and_sort_links(current_yaml, all_files)
    let weights = {}
    let tags = get(a:current_yaml, 'tags', [])
    let links = get(a:current_yaml, 'links', [])

    for file in a:all_files
        let file_yaml = s:get_yaml_front_matter(file)
        let file_score = 0

        if !empty(file_yaml)
            " Weight by tags
            for tag in tags
                if index(get(file_yaml, 'tags', []), tag) != -1
                    let file_score += 10  " Higher weight for tag matches
                endif
            endfor

            " Weight by existing links
            for link in links
                if fnamemodify(file, ':t:r') == link
                    let file_score += 20  " High weight for direct link matches
                endif
            endfor

            " Add other weighting strategies here (e.g., recency, frequency)

            if file_score > 0
                let weights[file] = file_score
            endif
        endif
    endfor

    " Sort by score in descending order
    return reverse(sort(weights, 'v:val'))
endfunction

"FUNCTION: Parse YAML front matter
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

"FUNCTION: Search and link notes
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
