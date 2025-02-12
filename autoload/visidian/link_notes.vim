"autoload/visidian/link_notes.vim
" PARA-aware note linking functionality

" FUNCTION: Create markdown link
function! s:create_markdown_link(file)
    return visidian#links#create_link(fnamemodify(a:file, ':.'), 'markdown')
endfunction

" FUNCTION: Update buffer after YAML changes
function! s:update_buffer()
    " Save current view
    let view = winsaveview()
    
    " Reload buffer
    edit
    
    " Restore view
    call winrestview(view)
endfunction

" FUNCTION: Handle link click
function! s:handle_link(link_info)
    let link = visidian#links#parse_link(a:link_info.path)
    call visidian#debug#debug('LINK', 'Handling link: ' . string(link))
    
    if link.type == 'external'
        call visidian#debug#info('LINK', 'Opening external link: ' . link.path)
        " Open external links in browser
        if has('unix')
            call system('xdg-open ' . shellescape(link.path) . ' &')
        elseif has('macunix')
            call system('open ' . shellescape(link.path) . ' &')
        elseif has('win32')
            call system('start ' . shellescape(link.path))
        endif
    else
        " Handle internal links
        if link.path =~ '^\$VAULT_PATH:'
            let target = substitute(link.path, '^\$VAULT_PATH:', g:visidian_vault_path, '')
        else
            let current_dir = expand('%:p:h')
            let target = resolve(current_dir . '/' . link.path)
        endif
        
        call visidian#debug#debug('LINK', 'Resolved internal link target: ' . target)
        
        if filereadable(target)
            execute 'edit ' . fnameescape(target)
        else
            call visidian#debug#error('LINK', 'Link target not found: ' . target)
            echohl WarningMsg
            echo "Link target not found: " . target
            echohl None
        endif
    endif
endfunction

" FUNCTION: Link Notes
function! visidian#link_notes#link_notes()
    " Check if vault exists
    if empty(g:visidian_vault_path)
        call visidian#debug#error('LINK', 'No vault path set')
        echohl ErrorMsg
        echo "No vault path set. Please create or set a vault first."
        echohl None
        return 0
    endif

    " Normalize vault path
    let vault_path = substitute(g:visidian_vault_path, '[\/]\+$', '', '')
    if g:visidian_debug
        call visidian#debug#debug('LINK', 'Using vault path: ' . vault_path)
    endif

    " Get all markdown files in the vault
    let vault_files = []
    for para_folder in ['Projects', 'Areas', 'Resources', 'Archive']
        let folder_path = vault_path . '/' . para_folder
        if isdirectory(folder_path)
            let files = globpath(folder_path, '**/*.md', 0, 1)
            call extend(vault_files, files)
        endif
    endfor

    if empty(vault_files)
        call visidian#debug#error('LINK', 'No markdown files found in vault')
        echohl WarningMsg
        echo "No markdown files found in vault"
        echohl None
        return 0
    endif

    " Get current file's YAML frontmatter
    let current_file = expand('%:p')
    let current_yaml = visidian#links#get_yaml_front_matter(current_file)

    " Weight and sort files based on tags and existing links
    let matches = s:weight_and_sort_links(current_yaml, vault_files)

    " Present options to user
    echo "Found " . len(matches) . " potential link targets."
    echo "Top matches:"
    let i = 0
    for [file, weight] in matches[:4]
        echo printf("%d: %s (relevance: %.2f)", i, fnamemodify(file, ':.'), weight)
        let i += 1
    endfor

    echo "\nOptions:"
    echo "1. Add link to YAML frontmatter"
    echo "2. Insert markdown link at cursor"
    echo "3. Cancel"

    let choice = input("Choose an option (1-3): ")
    if choice !~ '^[1-3]$'
        echo "\nInvalid choice"
        return 0
    endif

    if choice == '3'
        echo "\nCancelled"
        return 0
    endif

    let idx = str2nr(input("\nSelect file (0-" . min([4, len(matches)-1]) . "): "))
    if idx >= 0 && idx < len(matches)
        let selected_file = matches[idx][0]
        
        if choice == '1'
            " Update YAML frontmatter
            let yaml = visidian#links#get_yaml_front_matter(current_file)
            let yaml.links = get(yaml, 'links', [])
            call add(yaml.links, fnamemodify(selected_file, ':.'))
            call s:update_yaml_frontmatter(current_file, yaml)
            call s:update_buffer()
            echo "\nAdded link to YAML frontmatter"
        else
            " Insert markdown link at cursor
            let link = s:create_markdown_link(selected_file)
            execute "normal! a" . link
            echo "\nInserted markdown link"
        endif
        return 1
    endif

    echo "\nInvalid selection"
    return 0
endfunction

" FUNCTION: Weight and sort potential link targets
function! s:weight_and_sort_links(current_yaml, all_files)
    let weights = {}
    let tags = get(a:current_yaml, 'tags', [])
    let links = get(a:current_yaml, 'links', [])
    
    " Calculate weights for each file
    for file in a:all_files
        let weight = 0.0
        let file_yaml = visidian#links#get_yaml_front_matter(file)
        let file_tags = get(file_yaml, 'tags', [])
        
        " Weight based on shared tags
        for tag in file_tags
            if index(tags, tag) >= 0
                let weight += 1.0
            endif
        endfor
        
        " Weight based on existing links
        for link in links
            if link =~ fnamemodify(file, ':t:r')
                let weight += 0.5
            endif
        endfor
        
        " Weight based on PARA location
        let current_para = s:get_para_location(expand('%:p'))
        let file_para = s:get_para_location(file)
        if !empty(current_para) && current_para == file_para
            let weight += 0.3
        endif
        
        let weights[file] = weight
    endfor
    
    " Sort files by weight
    let sorted = items(weights)
    call sort(sorted, {a, b -> b[1] - a[1]})
    return sorted
endfunction

" FUNCTION: Get PARA location of a file
function! s:get_para_location(file)
    let path = a:file
    if path =~? '/Projects/'
        return 'Projects'
    elseif path =~? '/Areas/'
        return 'Areas'
    elseif path =~? '/Resources/'
        return 'Resources'
    elseif path =~? '/Archive/'
        return 'Archive'
    endif
    return ''
endfunction

" FUNCTION: Update YAML frontmatter in file
function! s:update_yaml_frontmatter(file, yaml)
    call visidian#debug#debug('LINK', 'Updating YAML frontmatter in: ' . a:file)
    
    try
        let lines = readfile(a:file)
        let new_lines = []
        let in_yaml = 0
        let yaml_end = 0
        
        " Check if file starts with YAML frontmatter
        if len(lines) > 0 && lines[0] =~ '^---\s*$'
            let in_yaml = 1
            call add(new_lines, '---')
            
            " Add all YAML fields
            if has_key(a:yaml, 'tags') && !empty(a:yaml.tags)
                call add(new_lines, 'tags:')
                for tag in a:yaml.tags
                    call add(new_lines, '  - ' . tag)
                endfor
            endif
            
            if has_key(a:yaml, 'links') && !empty(a:yaml.links)
                call add(new_lines, 'links:')
                for link in a:yaml.links
                    call add(new_lines, '  - ' . link)
                endfor
            endif
            
            " Add other fields from original YAML
            let skip_field = 0
            for line in lines[1:]
                if line =~ '^---\s*$'
                    let yaml_end = 1
                    call add(new_lines, '---')
                    break
                endif
                
                if line =~ '^\(tags\|links\):'
                    let skip_field = 1
                    continue
                endif
                
                if skip_field && line =~ '^\s\+-'
                    continue
                endif
                
                let skip_field = 0
                call add(new_lines, line)
            endfor
        endif
        
        " Add rest of file
        if yaml_end
            call extend(new_lines, lines[len(new_lines):])
        else
            " Create new YAML frontmatter
            let new_lines = ['---']
            if has_key(a:yaml, 'tags') && !empty(a:yaml.tags)
                call add(new_lines, 'tags:')
                for tag in a:yaml.tags
                    call add(new_lines, '  - ' . tag)
                endfor
            endif
            
            if has_key(a:yaml, 'links') && !empty(a:yaml.links)
                call add(new_lines, 'links:')
                for link in a:yaml.links
                    call add(new_lines, '  - ' . link)
                endfor
            endif
            
            call add(new_lines, '---')
            call extend(new_lines, lines)
        endif
        
        " Write back to file
        call writefile(new_lines, a:file)
        return 1
    catch
        call visidian#debug#error('LINK', 'Failed to update YAML frontmatter: ' . v:exception)
        return 0
    endtry
endfunction
