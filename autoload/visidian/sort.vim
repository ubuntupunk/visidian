"autoload/visidian/sort.vim

" FUNCTION: Sorting strategy based on file content, tags, and links
function! visidian#sort#sort()
    if g:visidian_vault_path == ''
        call visidian#debug#error('PARA', 'No vault path set')
        echohl ErrorMsg
        echo "No vault path set. Please create or set a vault first."
        echohl None
        return
    endif

    " Ensure PARA directories exist
    let para_dirs = ['projects', 'areas', 'resources', 'archives']
    for dir in para_dirs
        let full_dir = g:visidian_vault_path . dir
        if !isdirectory(full_dir)
            call visidian#debug#info('PARA', 'Creating directory: ' . full_dir)
            call mkdir(full_dir, 'p')
        endif
    endfor

    " Get all markdown files
    let files = globpath(g:visidian_vault_path, '**/*.md', 0, 1)
    call visidian#debug#info('PARA', 'Found ' . len(files) . ' markdown files to sort')

    let moved_count = 0
    for file in files
        let file_path = substitute(file, '^' . g:visidian_vault_path, '', '')
        call visidian#debug#debug('PARA', 'Processing file: ' . file_path)
        
        let dest_dir = s:determine_directory(file)
        if dest_dir == ''
            call visidian#debug#warn('PARA', 'Could not determine directory for: ' . file_path)
            continue
        endif
        
        let current_dir = fnamemodify(file, ':h')
        if dest_dir != current_dir
            " Move file
            let new_path = g:visidian_vault_path . dest_dir . '/' . fnamemodify(file, ':t')
            call visidian#debug#debug('PARA', 'Moving file to: ' . dest_dir)
            
            try
                call rename(file, new_path)
                let moved_count += 1
                call visidian#debug#info('PARA', 'Moved: ' . file_path . ' to ' . dest_dir)
                echo "Moved: " . file_path . " to " . dest_dir
                
                " Update YAML front matter if needed
                call s:update_yaml_front_matter(new_path)
            catch
                call visidian#debug#error('PARA', 'Failed to move file: ' . v:exception)
                echohl ErrorMsg
                echo "Failed to move file: " . file_path . " - " . v:exception
                echohl None
            endtry
        else
            call visidian#debug#debug('PARA', 'File already in correct directory: ' . file_path)
        endif
    endfor

    call visidian#debug#info('PARA', 'Sorting complete. Moved ' . moved_count . ' files')
    echo "Sorting complete. Moved " . moved_count . " files."
endfunction

" FUNCTION: Determine directory based on file content, tags, and links
function! s:determine_directory(file)
    call visidian#debug#debug('PARA', 'Determining directory for: ' . a:file)
    
    try
        let yaml = s:get_yaml_front_matter(a:file)
        let tags = get(yaml, 'tags', [])
        let links = get(yaml, 'links', [])
        
        call visidian#debug#trace('PARA', 'File tags: ' . string(tags))
        call visidian#debug#trace('PARA', 'File links: ' . string(links))
        
        " Calculate directory scores
        let scores = {'projects': 0, 'areas': 0, 'resources': 0, 'archives': 0}
        
        " Process tags
        for tag in tags
            let tag_lower = tolower(tag)
            for [dir, weights] in items(g:visidian_sort_logic)
                if has_key(weights, tag_lower)
                    let weight = weights[tag_lower]
                    let scores[dir] += weight
                    call visidian#debug#trace('PARA', 'Tag match: ' . tag . ' -> ' . dir . ' (+' . weight . ')')
                endif
            endfor
        endfor
        
        " Find highest scoring directory
        let max_score = 0
        let best_dir = ''
        for [dir, score] in items(scores)
            call visidian#debug#trace('PARA', 'Directory score: ' . dir . ' = ' . score)
            if score > max_score
                let max_score = score
                let best_dir = dir
            endif
        endfor
        
        " Use default if no strong match
        if max_score == 0
            let best_dir = 'resources'
            call visidian#debug#debug('PARA', 'No strong directory match, using default: resources')
        else
            call visidian#debug#debug('PARA', 'Selected directory: ' . best_dir . ' (score: ' . max_score . ')')
        endif
        
        return best_dir
    catch
        call visidian#debug#error('PARA', 'Failed to determine directory: ' . v:exception)
        return ''
    endtry
endfunction

" FUNCTION: Update YAML front matter after moving file
function! s:update_yaml_front_matter(file)
    call visidian#debug#debug('PARA', 'Updating YAML front matter for: ' . a:file)
    
    try
        let lines = readfile(a:file)
        let yaml_start = -1
        let yaml_end = -1
        
        " Find YAML front matter
        let i = 0
        while i < len(lines)
            if lines[i] =~ '^---\s*$'
                if yaml_start == -1
                    let yaml_start = i
                else
                    let yaml_end = i
                    break
                endif
            endif
            let i += 1
        endwhile
        
        if yaml_start == -1 || yaml_end == -1
            call visidian#debug#warn('PARA', 'No valid YAML front matter found')
            return
        endif
        
        " Update directory field in YAML
        let yaml_lines = lines[yaml_start+1:yaml_end-1]
        let dir_updated = 0
        let i = 0
        while i < len(yaml_lines)
            if yaml_lines[i] =~ '^directory:'
                let yaml_lines[i] = 'directory: ' . fnamemodify(a:file, ':h:t')
                let dir_updated = 1
                call visidian#debug#trace('PARA', 'Updated directory field in YAML')
                break
            endif
            let i += 1
        endwhile
        
        " Add directory field if not present
        if !dir_updated
            call add(yaml_lines, 'directory: ' . fnamemodify(a:file, ':h:t'))
            call visidian#debug#trace('PARA', 'Added directory field to YAML')
        endif
        
        " Write updated content back to file
        let updated_lines = lines[0:yaml_start] + yaml_lines + lines[yaml_end:]
        call writefile(updated_lines, a:file)
        call visidian#debug#info('PARA', 'Updated YAML front matter successfully')
    catch
        call visidian#debug#error('PARA', 'Failed to update YAML front matter: ' . v:exception)
    endtry
endfunction

" FUNCTION: Get YAML front matter from file
function! s:get_yaml_front_matter(file)
    call visidian#debug#trace('PARA', 'Reading YAML from: ' . a:file)
    
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
        call visidian#debug#trace('PARA', 'Parsed YAML: ' . string(yaml))
        return yaml
    catch
        call visidian#debug#error('PARA', 'Failed to read/parse YAML: ' . v:exception)
        throw v:exception
    endtry
endfunction
