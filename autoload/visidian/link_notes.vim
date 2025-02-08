"autoload/visidian/link_notes.vim

" FUNCTION: Check if YAML parser is available
function! s:yaml_parser_available()
    let available = exists('*yaml#decode')
    call visidian#debug#debug('CORE', 'YAML parser available: ' . available)
    return available
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
            " Get all markdown files in this folder and its subfolders
            let folder_files = glob(folder_path . '/**/*.md', 0, 1)
            let vault_files += folder_files
            call visidian#debug#trace('CORE', 'Found ' . len(folder_files) . ' files in ' . para_folder)
        else
            call visidian#debug#debug('CORE', 'Directory not found: ' . folder_path)
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
    call visidian#debug#debug('CORE', 'Processing current file: ' . current_file)

    " Remove current file from the list if it exists
    let vault_files = filter(vault_files, 'v:val !=# current_file')
    call visidian#debug#debug('CORE', 'Found ' . len(vault_files) . ' potential link targets')

    if empty(vault_files)
        call visidian#debug#warn('CORE', 'No other markdown files found in vault')
        echohl WarningMsg
        echo "No other markdown files found in vault."
        echohl None
        return 0
    endif

    " Check for YAML parser
    if !s:yaml_parser_available()
        call visidian#debug#error('CORE', 'YAML parser not available')
        echohl ErrorMsg
        echo "YAML parser not available. Please install vim-yaml."
        echohl None
        return 0
    endif

    " Read current file's YAML front matter
    try
        let current_yaml = s:get_yaml_front_matter(current_file)
        call visidian#debug#debug('CORE', 'Current file YAML: ' . string(current_yaml))
    catch
        call visidian#debug#error('CORE', 'Failed to parse YAML: ' . v:exception)
        echohl ErrorMsg
        echo "Failed to parse YAML front matter: " . v:exception
        echohl None
        return 0
    endtry

    " Weight and sort potential links
    let weighted_files = s:weight_and_sort_links(current_yaml, vault_files)
    call visidian#debug#debug('CORE', 'Weighted ' . len(weighted_files) . ' potential links')

    " Present top matches to user
    let max_suggestions = 10
    let top_matches = weighted_files[0:max_suggestions-1]
    
    call visidian#debug#info('CORE', 'Presenting top ' . len(top_matches) . ' matches')
    echo "Top related files:"
    let i = 1
    for [file, weight] in top_matches
        echo i . ". " . fnamemodify(file, ':t:r') . " (score: " . weight . ")"
        let i += 1
    endfor

    let choice = input("Select file to link (1-" . len(top_matches) . ", or 0 to cancel): ")
    if choice > 0 && choice <= len(top_matches)
        let selected_file = top_matches[choice-1][0]
        call s:create_link(selected_file)
        call visidian#debug#info('CORE', 'Created link to: ' . selected_file)
        return 1
    else
        call visidian#debug#info('CORE', 'Link creation cancelled')
        echo "Link creation cancelled."
        return 0
    endif
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
