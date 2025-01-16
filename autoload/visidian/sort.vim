"autoload/visidian/sort.vim

" FUNCTION: Sorting strategy based on file content, tags, and links
function! visidian#sort#sort()
    if g:visidian_vault_path == ''
        echoerr "No vault path set. Please create or set a vault first."
        return
    endif

    " Ensure PARA directories exist
    let para_dirs = ['projects', 'areas', 'resources', 'archives']
    for dir in para_dirs
        call mkdir(g:visidian_vault_path . dir, 'p')
    endfor

    " Get all markdown files
    let files = globpath(g:visidian_vault_path, '**/*.md', 0, 1)

    for file in files
        let file_path = substitute(file, '^' . g:visidian_vault_path, '', '')
        let dest_dir = s:determine_directory(file)
        
        if dest_dir != '' && dest_dir != fnamemodify(file, ':h')
            " Move file
            let new_path = g:visidian_vault_path . dest_dir . '/' . fnamemodify(file, ':t')
            call rename(file, new_path)
            echo "Moved: " . file_path . " to " . dest_dir . '/' . fnamemodify(file, ':t')
            
            " Update YAML front matter if needed
            call s:update_yaml_front_matter(new_path)
        endif
    endfor

    echo "Sorting complete."
endfunction

" FUNCTION: Determine directory based on file content, tags, and links
function! s:determine_directory(file)
    let yaml = s:get_yaml_front_matter(a:file)
    let tags = get(yaml, 'tags', [])
    let links = get(yaml, 'links', [])
    
    " Use the same logic from file_creation.vim
    let scores = {'projects': 0, 'areas': 0, 'resources': 0, 'archives': 0}
    let default_dir = 'resources'
    
    for tag in tags
        for [dir, tag_weights] in items(g:visidian_sort_logic)
            if has_key(tag_weights, tolower(tag))
                let scores[dir] += tag_weights[tolower(tag)]
            endif
        endfor
        if has_key(g:visidian_gtd_logic, tolower(tag))
            let scores[g:visidian_gtd_logic[tolower(tag)]] += 15
        endif
    endfor

    for link in links
        " Here we might want to check link destinations or infer from link names
    endfor

    let max_score = max(values(scores))
    let best_dirs = filter(keys(scores), {_, v -> scores[v] == max_score})

    " If there's a tie or no clear match, go with default or first match
    return len(best_dirs) > 0 ? best_dirs[0] : default_dir
endfunction

" FUNCTION: Update YAML front matter if it doesn't exist or needs enhancement
function! s:update_yaml_front_matter(file)
    let lines = readfile(a:file)
    let yaml_start = match(lines, '^---$')
    let yaml_end = match(lines, '^---$', yaml_start + 1)
    
    if yaml_start == -1 || yaml_end == -1
        " No front matter, add it
        let filename = fnamemodify(a:file, ':t:r')
        let suggested_tags = s:suggest_tags(a:file)
        let suggested_links = s:suggest_links(a:file)
        
        call insert(lines, '---', 0)
        call extend(lines, ['title: ' . filename, 'date: ' . strftime('%Y-%m-%d %H:%M:%S'), 'tags: ' . json_encode(suggested_tags), 'links: ' . json_encode(suggested_links), '---'], 0)
        call writefile(lines, a:file)
        echo "Added YAML front matter to: " . a:file
    else
        " TODO: Enhance existing front matter based on content if needed
    endif
endfunction

" FUNCTION: Suggest tags based on file content
function! s:suggest_tags(file)
    let content = join(readfile(a:file), ' ')
    " Simple tag suggestion based on common words or phrases
    let common_words = ['project', 'task', 'area', 'resource', 'archive']
    return filter(common_words, {_, w -> content =~? '\V' . w})
endfunction

" FUNCTION: Suggest links, could leverage link_notes functionality
function! s:suggest_links(file)
    " Here you might want to call visidian#link_notes#link_notes() to get suggested links
    " But for simplicity, we'll just return an empty list for now
    return []
endfunction

" FUNCTION: Helper function to get YAML front matter
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
    return visidian#link_notes#s:get_yaml_front_matter(a:file)
endfunction
