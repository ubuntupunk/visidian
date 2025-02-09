" autoload/visidian/bookmarking.vim:
" Provides bookmark management for Visidian notes using GTD and PARA methodologies

" Initialize global settings
if !exists('g:visidian_bookmark_last_note')
    let g:visidian_bookmark_last_note = 1
    call visidian#debug#debug('BOOK', 'Initialized bookmarking system')
endif

" Store bookmarks in JSON format in a dedicated file
let s:bookmark_file = get(g:, 'visidian_bookmark_file', '')
if empty(s:bookmark_file) && !empty(g:visidian_vault_path)
    let s:bookmark_file = expand(g:visidian_vault_path . '/.visidian_bookmarks.json')
    call visidian#debug#debug('BOOK', 'Set bookmark file: ' . s:bookmark_file)
endif

" Define base categories (these cannot be modified)
let s:base_categories = {
    \ 'gtd': ['inbox', 'next', 'waiting', 'someday', 'reference', 'done'],
    \ 'para': ['projects', 'areas', 'resources', 'archives'],
    \ 'books': ['reading', 'to-read', 'finished', 'reference']
    \ }

" Initialize categories with base categories
let s:categories = deepcopy(s:base_categories)

" FUNCTION: Save categories to file
function! s:save_categories() abort
    let categories_file = expand(g:visidian_vault_path . '/.visidian_categories.json')
    let custom_categories = {}
    
    " Only save custom categories (not base ones)
    for [category, subcats] in items(s:categories)
        if !has_key(s:base_categories, category)
            let custom_categories[category] = subcats
        endif
    endfor
    
    call writefile([json_encode(custom_categories)], categories_file)
    call visidian#debug#debug('BOOK', 'Saved categories to: ' . categories_file)
endfunction

" FUNCTION: Load categories from file
function! s:load_categories() abort
    let categories_file = expand(g:visidian_vault_path . '/.visidian_categories.json')
    
    " Start with base categories
    let s:categories = deepcopy(s:base_categories)
    
    if filereadable(categories_file)
        let content = join(readfile(categories_file), '')
        let custom_categories = json_decode(content)
        
        " Merge custom categories
        call extend(s:categories, custom_categories)
        call visidian#debug#debug('BOOK', 'Loaded categories from: ' . categories_file)
    endif
endfunction

" Buffer name for stats
let s:stats_buffer_name = 'Visidian-Bookmark-Stats'

" Maintain bookmarks in memory
let s:bookmarks = {}

" FUNCTION: Load bookmarks from file
function! s:load_bookmarks()
    call visidian#debug#debug('BOOK', 'Loading bookmarks from: ' . s:bookmark_file)
    if filereadable(s:bookmark_file)
        try
            let content = readfile(s:bookmark_file)
            let s:bookmarks = json_decode(join(content, '\n'))
            call visidian#debug#info('BOOK', 'Loaded ' . len(s:bookmarks) . ' bookmarks')
        catch
            call visidian#debug#error('BOOK', 'Failed to load bookmarks: ' . v:exception)
            let s:bookmarks = {}
        endtry
    endif
endfunction

" FUNCTION: Save bookmarks to file
function! s:save_bookmarks()
    call visidian#debug#debug('BOOK', 'Saving bookmarks to: ' . s:bookmark_file)
    try
        call writefile([json_encode(s:bookmarks)], s:bookmark_file)
        call visidian#debug#info('BOOK', 'Saved ' . len(s:bookmarks) . ' bookmarks')
    catch
        call visidian#debug#error('BOOK', 'Failed to save bookmarks: ' . v:exception)
    endtry
endfunction

" FUNCTION: Add a bookmark with category
function! s:add_bookmark(name, category)
    call visidian#debug#debug('BOOK', 'Adding bookmark: ' . a:name . ' to category: ' . a:category)
    let path = expand('%:p')
    
    if empty(g:visidian_vault_path)
        call visidian#debug#error('BOOK', 'No vault path set')
        echohl ErrorMsg
        echo "No vault path set. Please set a vault first."
        echohl None
        return 0
    endif
    
    if stridx(path, g:visidian_vault_path) == 0
        if !has_key(s:bookmarks, a:category)
            let s:bookmarks[a:category] = {}
        endif
        
        " Get first 5 lines for preview, properly escaped
        let preview_lines = getline(1, min([line('$'), 5]))
        let preview = join(preview_lines, "\n")
        
        let s:bookmarks[a:category][a:name] = {
            \ 'path': path,
            \ 'timestamp': localtime(),
            \ 'title': getline(1),
            \ 'preview': preview
            \ }
        
        call s:save_bookmarks()
        call visidian#debug#info('BOOK', 'Added bookmark: ' . a:name . ' -> ' . path)
        echo "Added bookmark: " . a:name . " to " . a:category
        return 1
    else
        call visidian#debug#warn('BOOK', 'File not in vault: ' . path)
        echohl WarningMsg
        echo "Cannot bookmark files outside the vault"
        echohl None
        return 0
    endif
endfunction

" FUNCTION: Remove a bookmark
function! s:remove_bookmark(category, name)
    call visidian#debug#debug('BOOK', 'Removing bookmark: ' . a:name . ' from category: ' . a:category)
    if has_key(s:bookmarks, a:category) && has_key(s:bookmarks[a:category], a:name)
        unlet s:bookmarks[a:category][a:name]
        call s:save_bookmarks()
        call visidian#debug#info('BOOK', 'Removed bookmark: ' . a:name)
        echo "Removed bookmark: " . a:name
        return 1
    else
        call visidian#debug#warn('BOOK', 'Bookmark not found: ' . a:name)
        echohl WarningMsg
        echo "Bookmark not found: " . a:name
        echohl None
        return 0
    endif
endfunction

" FUNCTION: Get formatted bookmark list for FZF
function! s:get_formatted_bookmarks()
    let formatted = []
    for [category, bookmarks] in items(s:bookmarks)
        for [name, data] in items(bookmarks)
            call add(formatted, category . ' | ' . name . ' | ' . data.title)
        endfor
    endfor
    return formatted
endfunction

" FUNCTION: Toggle stats buffer
function! s:toggle_stats_buffer()
    let bufnr = bufnr(s:stats_buffer_name)
    if bufnr != -1
        " Buffer exists, toggle its visibility
        let winnr = bufwinnr(bufnr)
        if winnr != -1
            " Buffer is visible, close it
            execute winnr . 'wincmd c'
            call visidian#debug#debug('BOOK', 'Closed stats buffer')
        else
            " Buffer exists but is hidden, show it
            execute 'sbuffer ' . bufnr
            call visidian#debug#debug('BOOK', 'Showed stats buffer')
        endif
    else
        " Buffer doesn't exist, create it
        call s:show_statistics()
    endif
endfunction

" FUNCTION: Main bookmark menu
function! visidian#bookmarking#menu()
    call visidian#debug#debug('BOOK', 'Opening bookmark menu')
    
    " Ensure vault path is set
    if !visidian#load_vault_path()
        call visidian#debug#warn('BOOK', "No vault configured. Let's set one up!")
        if !visidian#create_vault()
            return
        endif
    endif
    
    if empty(g:visidian_vault_path)
        call visidian#debug#error('BOOK', 'No vault path set')
        echohl ErrorMsg
        echo "No vault path set. Please set a vault first."
        echohl None
        return
    endif
    
    if !exists('*fzf#run')
        call visidian#debug#error('BOOK', 'FZF not available')
        echohl ErrorMsg
        echo "FZF not available. Please install junegunn/fzf.vim"
        echohl None
        return
    endif
    
    let actions = [
        \ 'add:gtd - Add to GTD category',
        \ 'add:para - Add to PARA category',
        \ 'add:books - Add to Books category',
        \ 'add:custom - Add to custom category',
        \ 'category:new - Create new category',
        \ 'category:edit - Edit category',
        \ 'category:delete - Delete category',
        \ 'category:sort - Sort categories',
        \ 'remove - Remove a bookmark',
        \ 'view - View/jump to bookmark',
        \ 'stats - Toggle statistics view'
        \ ]
    
    call fzf#run({
        \ 'source': actions,
        \ 'sink': function('s:handle_menu_selection'),
        \ 'options': '--prompt "Bookmark Actions> "'
        \ })
endfunction

" FUNCTION: Handle menu selection
function! s:handle_menu_selection(selection)
    let action = split(a:selection, ' - ')[0]
    
    if action =~ '^add:'
        let category_type = split(action, ':')[1]
        call s:show_category_menu(category_type)
    elseif action == 'category:new'
        call s:create_new_category()
    elseif action == 'category:edit'
        call s:edit_category()
    elseif action == 'category:delete'
        call s:delete_category()
    elseif action == 'category:sort'
        call s:sort_categories()
    elseif action == 'remove'
        call s:show_remove_menu()
    elseif action == 'view'
        call s:show_view_menu()
    elseif action == 'stats'
        call s:toggle_stats_buffer()
    endif
endfunction

" FUNCTION: Create new category
function! s:create_new_category()
    let category = input('Enter new category name: ')
    if empty(category)
        call visidian#debug#debug('BOOK', 'Category creation cancelled')
        return
    endif
    
    " Sanitize category name
    let category = substitute(category, '[^a-zA-Z0-9_-]', '', 'g')
    let category = tolower(category)
    
    if has_key(s:categories, category)
        call visidian#debug#warn('BOOK', 'Category already exists: ' . category)
        echohl WarningMsg
        echo "Category already exists"
        echohl None
        return
    endif
    
    " Get subcategories
    let subcats = input('Enter subcategories (comma-separated): ')
    if empty(subcats)
        let s:categories[category] = ['default']
    else
        let subcats = split(subcats, ',')
        call map(subcats, {_, v -> substitute(tolower(trim(v)), '[^a-zA-Z0-9_-]', '', 'g')})
        let s:categories[category] = subcats
    endif
    
    call s:save_categories()
    call visidian#debug#info('BOOK', 'Created new category: ' . category)
    echo "Created category '" . category . "' with subcategories: " . join(s:categories[category], ', ')
endfunction

" FUNCTION: Show category menu for adding bookmarks
function! s:show_category_menu(type)
    if a:type == 'custom'
        let custom_cats = filter(keys(s:categories), 'v:val != "gtd" && v:val != "para" && v:val != "books"')
        if empty(custom_cats)
            call visidian#debug#warn('BOOK', 'No custom categories exist')
            echohl WarningMsg
            echo "No custom categories exist. Create one first."
            echohl None
            return
        endif
        call fzf#run({
            \ 'source': custom_cats,
            \ 'sink': function('s:handle_custom_category_selection'),
            \ 'options': '--prompt "Select Custom Category> "'
            \ })
    else
        let categories = s:categories[a:type]
        call fzf#run({
            \ 'source': categories,
            \ 'sink': function('s:handle_category_selection', [a:type]),
            \ 'options': '--prompt "Select Category> "'
            \ })
    endif
endfunction

" FUNCTION: Handle custom category selection
function! s:handle_custom_category_selection(category)
    call s:show_category_menu(a:category)
endfunction

" FUNCTION: Handle category selection
function! s:handle_category_selection(type, category)
    let name = input('Enter bookmark name: ')
    if !empty(name)
        call s:add_bookmark(name, a:category)
    endif
endfunction

" FUNCTION: Edit category
function! s:edit_category()
    let custom_cats = filter(keys(s:categories), '!has_key(s:base_categories, v:val)')
    if empty(custom_cats)
        call visidian#debug#warn('BOOK', 'No custom categories to edit')
        echohl WarningMsg
        echo "No custom categories exist. Create one first."
        echohl None
        return
    endif
    
    call fzf#run({
        \ 'source': custom_cats,
        \ 'sink': function('s:handle_edit_category'),
        \ 'options': '--prompt "Select Category to Edit> "'
        \ })
endfunction

" FUNCTION: Handle edit category selection
function! s:handle_edit_category(category)
    let subcats = join(s:categories[a:category], ', ')
    let new_subcats = input('Edit subcategories (comma-separated): ', subcats)
    
    if !empty(new_subcats)
        let subcats = split(new_subcats, ',')
        call map(subcats, {_, v -> substitute(tolower(trim(v)), '[^a-zA-Z0-9_-]', '', 'g')})
        let s:categories[a:category] = subcats
        call s:save_categories()
        call visidian#debug#info('BOOK', 'Updated category: ' . a:category)
        echo "Updated category '" . a:category . "' with subcategories: " . join(subcats, ', ')
    endif
endfunction

" FUNCTION: Delete category
function! s:delete_category()
    let custom_cats = filter(keys(s:categories), '!has_key(s:base_categories, v:val)')
    if empty(custom_cats)
        call visidian#debug#warn('BOOK', 'No custom categories to delete')
        echohl WarningMsg
        echo "No custom categories exist to delete."
        echohl None
        return
    endif
    
    call fzf#run({
        \ 'source': custom_cats,
        \ 'sink': function('s:handle_delete_category'),
        \ 'options': '--prompt "Select Category to Delete> "'
        \ })
endfunction

" FUNCTION: Handle delete category selection
function! s:handle_delete_category(category)
    " Check if category has bookmarks
    if has_key(s:bookmarks, a:category) && !empty(s:bookmarks[a:category])
        let confirm = input('Category has bookmarks. Delete anyway? (y/N): ')
        if tolower(confirm) != 'y'
            echo "Category deletion cancelled"
            return
        endif
        " Remove bookmarks in this category
        unlet s:bookmarks[a:category]
        call s:save_bookmarks()
    endif
    
    unlet s:categories[a:category]
    call s:save_categories()
    call visidian#debug#info('BOOK', 'Deleted category: ' . a:category)
    echo "Deleted category '" . a:category . "'"
endfunction

" FUNCTION: Sort categories
function! s:sort_categories()
    let custom_cats = filter(keys(s:categories), '!has_key(s:base_categories, v:val)')
    if empty(custom_cats)
        call visidian#debug#warn('BOOK', 'No custom categories to sort')
        echohl WarningMsg
        echo "No custom categories exist to sort."
        echohl None
        return
    endif
    
    " Sort subcategories within each custom category
    for category in custom_cats
        call sort(s:categories[category])
    endfor
    
    call s:save_categories()
    call visidian#debug#info('BOOK', 'Sorted all custom categories')
    echo "Sorted subcategories in all custom categories"
endfunction

" FUNCTION: Show remove menu
function! s:show_remove_menu()
    call fzf#run({
        \ 'source': s:get_formatted_bookmarks(),
        \ 'sink': function('s:handle_remove_selection'),
        \ 'options': '--prompt "Select Bookmark to Remove> " --preview "echo {3..}"'
        \ })
endfunction

" FUNCTION: Handle remove selection
function! s:handle_remove_selection(selection)
    let parts = split(a:selection, ' | ')
    call s:remove_bookmark(parts[0], parts[1])
endfunction

" FUNCTION: Show view menu
function! s:show_view_menu()
    call fzf#run({
        \ 'source': s:get_formatted_bookmarks(),
        \ 'sink': function('s:handle_view_selection'),
        \ 'options': '--prompt "Select Bookmark> " --preview "echo {3..}"'
        \ })
endfunction

" FUNCTION: Handle view selection
function! s:handle_view_selection(selection)
    let parts = split(a:selection, ' | ')
    let category = parts[0]
    let name = parts[1]
    
    if has_key(s:bookmarks, category) && has_key(s:bookmarks[category], name)
        " Update view count
        let bookmark = s:bookmarks[category][name]
        let bookmark.views = get(bookmark, 'views', 0) + 1
        let bookmark.last_viewed = localtime()
        call s:save_bookmarks()
        
        execute 'edit ' . fnameescape(s:bookmarks[category][name].path)
        call visidian#debug#info('BOOK', 'Jumped to bookmark: ' . name)
    endif
endfunction

" FUNCTION: Calculate and show bookmark statistics
function! s:show_statistics()
    call visidian#debug#debug('BOOK', 'Generating bookmark statistics')
    
    " Initialize stats
    let l:stats = {
        \ 'total': 0,
        \ 'by_category': {},
        \ 'recent_adds': [],
        \ 'recent_views': [],
        \ 'most_viewed': {}
        \ }
    
    " Collect statistics
    for [l:category, l:bookmarks] in items(s:bookmarks)
        let l:stats.by_category[l:category] = len(l:bookmarks)
        let l:stats.total += len(l:bookmarks)
        
        for [l:name, l:data] in items(l:bookmarks)
            " Track recent additions (last 7 days)
            if localtime() - l:data.timestamp < 7 * 24 * 60 * 60
                call add(l:stats.recent_adds, {
                    \ 'category': l:category,
                    \ 'name': l:name,
                    \ 'title': l:data.title,
                    \ 'timestamp': l:data.timestamp
                    \ })
            endif
            
            " Track view count if available
            if has_key(l:data, 'views')
                let l:stats.most_viewed[l:category . '/' . l:name] = l:data.views
            endif
        endfor
    endfor
    
    " Sort recent additions by timestamp
    call sort(l:stats.recent_adds, {a, b -> b.timestamp - a.timestamp})
    
    " Create the statistics report
    let l:report = []
    call add(l:report, '=== Bookmark Statistics ===')
    call add(l:report, '')
    call add(l:report, 'Total Bookmarks: ' . l:stats.total)
    call add(l:report, '')
    call add(l:report, '--- By Category ---')
    
    " Show category counts
    let l:category_list = items(l:stats.by_category)
    let l:idx = 0
    while l:idx < len(l:category_list)
        let [l:cat, l:num] = l:category_list[l:idx]
        call add(l:report, printf('%-15s: %d', l:cat, l:num))
        let l:idx += 1
    endwhile
    
    call add(l:report, '')
    call add(l:report, '--- Recent Additions (7 days) ---')
    
    " Show recent additions
    let l:num_recent = 0
    let l:idx = 0
    while l:idx < min([len(l:stats.recent_adds), 5])
        let l:item = l:stats.recent_adds[l:idx]
        call add(l:report, printf('%s: %s (%s)',
            \ strftime('%Y-%m-%d', l:item.timestamp),
            \ l:item.name,
            \ l:item.category))
        let l:num_recent += 1
        let l:idx += 1
    endwhile
    if l:num_recent == 0
        call add(l:report, 'No recent additions')
    endif
    
    call add(l:report, '')
    call add(l:report, '--- Most Viewed ---')
    
    " Show most viewed
    let l:sorted_views = items(l:stats.most_viewed)
    call sort(l:sorted_views, {a, b -> b[1] - a[1]})
    let l:num_viewed = 0
    let l:idx = 0
    while l:idx < min([len(l:sorted_views), 5])
        let [l:path, l:views] = l:sorted_views[l:idx]
        call add(l:report, printf('%-30s: %d views', l:path, l:views))
        let l:num_viewed += 1
        let l:idx += 1
    endwhile
    if l:num_viewed == 0
        call add(l:report, 'No view statistics available')
    endif
    
    " Display the report in a new buffer
    let l:bufnr = bufnr(s:stats_buffer_name)
    if l:bufnr != -1
        execute 'bwipeout! ' . l:bufnr
    endif
    
    new
    execute 'file ' . s:stats_buffer_name
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nowrap
    setlocal nomodifiable
    setlocal filetype=markdown
    call setline(1, l:report)
    
    call visidian#debug#info('BOOK', 'Generated statistics report')
endfunction

" Load bookmarks and categories when the script is sourced
call s:load_bookmarks()
call s:load_categories()

" Set up single command
command! -nargs=0 VisidianBook call visidian#bookmarking#menu()
