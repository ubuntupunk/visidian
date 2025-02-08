"autoload/visidian/link_notes.vim

" FUNCTION: Check if YAML parser is available
function! s:yaml_parser_available()
    let available = exists('*yaml#decode')
    call visidian#debug#debug('CORE', 'YAML parser available: ' . available)
    return available
endfunction

" FUNCTION: Simple YAML parser fallback
function! s:simple_yaml_parse(text)
    let yaml = {}
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
                let value = split(value[1:-2], ',\s*')
            endif
            let yaml[key] = value
        endif
    endfor
    return yaml
endfunction

" FUNCTION: Get YAML front matter with fallback
function! s:get_yaml_front_matter(file)
    call visidian#debug#trace('CORE', 'Reading YAML from: ' . a:file)
    try
        let lines = readfile(a:file)
        let yaml_text = []
        let in_yaml = 0
        let yaml_end = 0
        
        for line in lines
            if line =~ '^---\s*$'
                if !in_yaml
                    let in_yaml = 1
                    continue
                else
                    let yaml_end = 1
                    break
                endif
            endif
            if in_yaml
                call add(yaml_text, line)
            endif
        endfor
        
        if !yaml_end
            throw 'No valid YAML front matter found'
        endif
        
        let yaml_str = join(yaml_text, "\n")
        if s:yaml_parser_available()
            let yaml = yaml#decode(yaml_str)
        else
            let yaml = s:simple_yaml_parse(yaml_str)
        endif
        
        call visidian#debug#trace('CORE', 'Parsed YAML: ' . string(yaml))
        return yaml
    catch
        call visidian#debug#warn('CORE', 'Failed to parse YAML: ' . v:exception . '. Using empty YAML.')
        return {'tags': [], 'links': []}
    endtry
endfunction

" FUNCTION: Create markdown link
function! s:create_markdown_link(file)
    let title = fnamemodify(a:file, ':t:r')
    let rel_path = fnamemodify(a:file, ':.')
    return '[' . title . '](' . rel_path . ')'
endfunction

"FUNCTION: Link Notes
function! visidian#link_notes#link_notes()
    " Check if vault exists
    if empty(g:visidian_vault_path)
        call visidian#debug#error('CORE', 'No vault path set')
        echohl ErrorMsg
        echo "No vault path set. Please create or set a vault first."
        echohl None
        return 0
    endif

    " Normalize vault path
    let vault_path = substitute(g:visidian_vault_path, '[\/]\+$', '', '')
    call visidian#debug#debug('CORE', 'Using vault path: ' . vault_path)

    " Get all markdown files in the vault
    let vault_files = []
    for para_folder in ['Projects', 'Areas', 'Resources', 'Archive']
        let folder_path = vault_path . '/' . para_folder
        if isdirectory(folder_path)
            let folder_files = glob(folder_path . '/**/*.md', 0, 1)
            let vault_files += folder_files
        endif
    endfor

    if empty(vault_files)
        call visidian#debug#warn('CORE', 'No markdown files found in vault')
        echohl WarningMsg
        echo "No markdown files found in vault."
        echohl None
        return 0
    endif

    " Get current file path
    let current_file = expand('%:p')
    if current_file !~# '\.md$'
        call visidian#debug#error('CORE', 'Current file is not markdown: ' . current_file)
        echohl ErrorMsg
        echo "Current file is not a markdown file."
        echohl None
        return 0
    endif

    " Remove current file from the list
    let vault_files = filter(vault_files, 'v:val !=# current_file')

    if empty(vault_files)
        call visidian#debug#warn('CORE', 'No other markdown files found in vault')
        echohl WarningMsg
        echo "No other markdown files found in vault."
        echohl None
        return 0
    endif

    " Ask user for link type
    echo "\nLink Type:"
    echo "1. YAML frontmatter link (metadata)"
    echo "2. Markdown link (in content)"
    echo "q. Cancel"
    
    let choice = input("\nEnter choice (1/2/q): ")
    echo "\n"
    
    if choice == 'q'
        echo "Operation cancelled."
        return 0
    endif

    " Get current file's YAML if needed
    let current_yaml = {}
    if choice == '1'
        try
            let current_yaml = s:get_yaml_front_matter(current_file)
        catch
            let current_yaml = {'tags': [], 'links': []}
        endtry
    endif

    " Weight and sort potential links
    let weighted_files = s:weight_and_sort_links(current_yaml, vault_files)

    " Present top matches to user
    let max_suggestions = 10
    let top_matches = weighted_files[0:max_suggestions-1]
    
    echo "Select file to link (0 to cancel):"
    let i = 1
    for [file, weight] in top_matches
        let display_name = fnamemodify(file, ':t')
        echo printf("%d. %s", i, display_name)
        let i += 1
    endfor

    let selection = input("\nEnter number: ")
    if selection == '0' || selection == ''
        echo "\nOperation cancelled."
        return 0
    endif

    let idx = str2nr(selection) - 1
    if idx >= 0 && idx < len(top_matches)
        let selected_file = top_matches[idx][0]
        
        if choice == '1'
            " Update YAML frontmatter
            let links = get(current_yaml, 'links', [])
            let new_link = fnamemodify(selected_file, ':t:r')
            if index(links, new_link) == -1
                call add(links, new_link)
                let current_yaml['links'] = links
                call s:update_yaml_frontmatter(current_file, current_yaml)
                echo "\nAdded YAML link to " . new_link
            else
                echo "\nLink already exists in YAML frontmatter."
            endif
        else
            " Insert markdown link at cursor
            let md_link = s:create_markdown_link(selected_file)
            let pos = getpos('.')
            call append(pos[1], md_link)
            echo "\nInserted markdown link: " . md_link
        endif
        
        return 1
    else
        echo "\nInvalid selection."
        return 0
    endif
endfunction

" FUNCTION: Update YAML frontmatter
function! s:update_yaml_frontmatter(file, yaml)
    let lines = readfile(a:file)
    let new_lines = []
    let in_yaml = 0
    let yaml_done = 0
    
    " Convert YAML to string format
    let yaml_lines = []
    for [key, value] in items(a:yaml)
        if type(value) == type([])
            let yaml_lines += [key . ': [' . join(value, ', ') . ']']
        else
            let yaml_lines += [key . ': ' . value]
        endif
    endfor
    
    " Update file content
    for line in lines
        if line =~ '^---\s*$'
            if !in_yaml
                let in_yaml = 1
                call add(new_lines, line)
                call extend(new_lines, yaml_lines)
            else
                let yaml_done = 1
                call add(new_lines, line)
            endif
        elseif !in_yaml || yaml_done
            call add(new_lines, line)
        endif
    endfor
    
    call writefile(new_lines, a:file)
endfunction

"FUNCTION: Get YAML front matter
function! s:get_yaml_front_matter(file)
    call visidian#debug#trace('CORE', 'Reading YAML from: ' . a:file)
    try
        let lines = readfile(a:file)
        let yaml_text = []
        let in_yaml = 0
        let yaml_end = 0
        
        for line in lines
            if line =~ '^---\s*$'
                if !in_yaml
                    let in_yaml = 1
                    continue
                else
                    let yaml_end = 1
                    break
                endif
            endif
            if in_yaml
                call add(yaml_text, line)
            endif
        endfor
        
        if !yaml_end
            throw 'No valid YAML front matter found'
        endif
        
        let yaml = yaml#decode(join(yaml_text, "\n"))
        call visidian#debug#trace('CORE', 'Parsed YAML: ' . string(yaml))
        return yaml
    catch
        call visidian#debug#error('CORE', 'Failed to read/parse YAML: ' . v:exception)
        throw v:exception
    endtry
endfunction

"FUNCTION: Weight and sort potential links
function! s:weight_and_sort_links(current_yaml, all_files)
    call visidian#debug#debug('CORE', 'Weighting potential links')
    let weights = {}
    let tags = get(a:current_yaml, 'tags', [])
    let links = get(a:current_yaml, 'links', [])
    
    call visidian#debug#trace('CORE', 'Current tags: ' . string(tags))
    call visidian#debug#trace('CORE', 'Current links: ' . string(links))

    for file in a:all_files
        try
            let yaml = s:get_yaml_front_matter(file)
            let file_tags = get(yaml, 'tags', [])
            let file_links = get(yaml, 'links', [])
            
            " Calculate weight based on shared tags and links
            let weight = 0
            
            " Tag matching
            for tag in tags
                if index(file_tags, tag) >= 0
                    let weight += 2
                    call visidian#debug#trace('CORE', 'Tag match in ' . file . ': ' . tag)
                endif
            endfor
            
            " Link matching
            for link in links
                if index(file_links, link) >= 0
                    let weight += 1
                    call visidian#debug#trace('CORE', 'Link match in ' . file . ': ' . link)
                endif
            endfor
            
            " Store weight if non-zero
            if weight > 0
                let weights[file] = weight
            endif
            
        catch
            call visidian#debug#warn('CORE', 'Failed to process file for weighting: ' . file)
            continue
        endtry
    endfor
    
    " Sort files by weight
    let sorted = sort(items(weights), {a, b -> b[1] - a[1]})
    call visidian#debug#debug('CORE', 'Sorted ' . len(sorted) . ' weighted files')
    return sorted
endfunction

"FUNCTION: Create link in current file
function! s:create_link(target_file)
    call visidian#debug#debug('CORE', 'Creating link to: ' . a:target_file)
    
    " Get relative path and create markdown link
    let rel_path = fnamemodify(a:target_file, ':t:r')
    let link = '[[' . rel_path . ']]'
    
    " Insert link at cursor position
    try
        execute "normal! a" . link . "\<Esc>"
        call visidian#debug#info('CORE', 'Link inserted successfully')
    catch
        call visidian#debug#error('CORE', 'Failed to insert link: ' . v:exception)
        echohl ErrorMsg
        echo "Failed to insert link: " . v:exception
        echohl None
    endtry
endfunction
