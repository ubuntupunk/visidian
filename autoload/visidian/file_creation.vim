" file autoload/visidian/file_creation.vim:

" Create a new markdown file (with YAML front matter) and suggest
" directory based upon tags and PARA formula

" Dictionary for common tags and their weights for each PARA directory
let s:para_logic = {
    \ 'projects': {'project': 10, 'task': 8, 'deadline': 5, 'goal': 7}, 
    \ 'areas': {'area': 10, 'responsibility': 8, 'habit': 6, 'routine': 6},
    \ 'resources': {'reference': 10, 'study': 8, 'learning': 7, 'research': 6},
    \ 'archives': {'archive': 10, 'completed': 8, 'historical': 6}
\ }

" Additional tags for GTD integration
let s:gtd_logic = {
    \ 'nextaction': 'projects', 
    \ 'waiting': 'projects', 
    \ 'someday': 'projects',
    \ 'context': 'areas'
\ }

"FUNCTION: Create File
function! visidian#file_creation#new_md_file()
    if g:visidian_vault_path == ''
        call visidian#debug#error('PARA', 'No vault path set')
        echohl ErrorMsg
        echo "No vault path set. Please create or set a vault first."
        echohl None
        return
    endif

    let name = input("Enter new markdown file name: ")
    if name == ''
        call visidian#debug#info('PARA', 'No file name provided')
        echo "No file name provided."
        return
    endif
    call visidian#debug#debug('PARA', 'Creating new file: ' . name)

    let tags = input("Enter tags for the file (comma-separated): ")
    let tags_list = map(split(tags, ','), 'trim(v:val)')
    call visidian#debug#debug('PARA', 'Tags: ' . string(tags_list))

    let links = input("Enter linked file names (comma-separated, without .md): ")
    let links_list = map(split(links, ','), 'trim(v:val)')
    call visidian#debug#debug('PARA', 'Links: ' . string(links_list))

    let suggested_dir = s:suggest_directory(tags_list)
    call visidian#debug#debug('PARA', 'Suggested directory: ' . suggested_dir)
    
    let confirmed_dir = input('Save file in directory? [' . suggested_dir . ']: ', suggested_dir)
    if empty(confirmed_dir)
        let confirmed_dir = suggested_dir
    endif
    call visidian#debug#debug('PARA', 'Confirmed directory: ' . confirmed_dir)

    " Remove trailing slash if present
    let confirmed_dir = substitute(confirmed_dir, '/$', '', '')

    " Ensure directory exists
    let full_dir = g:visidian_vault_path . confirmed_dir
    if !isdirectory(full_dir)
        call visidian#debug#info('PARA', 'Creating directory: ' . full_dir)
        try
            call mkdir(full_dir, 'p')
        catch
            call visidian#debug#error('PARA', 'Failed to create directory: ' . v:exception)
            echohl ErrorMsg
            echo "Failed to create directory: " . v:exception
            echohl None
            return
        endtry
    endif

    let full_path = full_dir . '/' . name . '.md'
    try
        exe 'edit ' . full_path

        call append(0, '---')
        call append(1, 'title: ' . name)
        call append(2, 'date: ' . strftime('%Y-%m-%d %H:%M:%S'))
        call append(3, 'tags: ' . json_encode(tags_list))
        call append(4, 'links: ' . json_encode(links_list))
        call append(5, '---')
        call append(6, '')
        call setpos('.', [0, 7, 1, 0]) " Move cursor below the front matter

        write
        echo "File created at: " . full_path
    catch /^Vim\%((\a\+)\)\=:E484/
        echoerr "Cannot create file: Permission denied or file already exists."
    endtry
endfunction

"FUNCTION: Suggest directory based on tags
function! s:suggest_directory(tags)
    call visidian#debug#debug('PARA', 'Suggesting directory for tags: ' . string(a:tags))
    
    let scores = {'projects': 0, 'areas': 0, 'resources': 0, 'archives': 0}
    let default_dir = 'resources'
    
" Score based on tags
    for tag in a:tags
        for [dir, tag_weights] in items(s:para_logic)
            if has_key(tag_weights, tolower(tag))
                let scores[dir] += tag_weights[tolower(tag)]
            endif
        endfor

" GTD tags directly suggest a directory
        if has_key(s:gtd_logic, tolower(tag))
            let scores[s:gtd_logic[tolower(tag)]] += 15 " High weight for direct GTD matches
        endif
    endfor
    
" Determine the highest scored directory
    let max_score = max(values(scores))
    let best_dirs = filter(keys(scores), {_, v -> scores[v] == max_score})

" If there's a tie, choose one based on order of preference (projects > areas > resources > archives)
    if len(best_dirs) > 1
        for dir in ['projects', 'areas', 'resources', 'archives']
            if index(best_dirs, dir) != -1
                return dir . '/' . s:suggest_subdir(dir, a:tags)
                endif
            endfor
    else
        return best_dirs[0] . '/' . s:suggest_subdir(best_dirs[0], a:tags)
    endif

    return default_dir
endfunction

"FUNCTION: Simple logic for suggesting subdirectories within PARA directories
function! s:suggest_subdir(dir, tags)
    if a:dir == 'projects'
        for tag in a:tags
            if tag =~? '\vclient|customer'
                return 'clients/'
            elseif tag =~? '\vteam|group'
                return 'teams/'
        endif
    endfor
        return 'general/'
    endif
    return ''
endfunction
