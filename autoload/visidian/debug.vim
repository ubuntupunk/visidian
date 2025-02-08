" Debug levels
let s:DEBUG_LEVELS = {
    \ 'ERROR': 0,
    \ 'WARN':  1,
    \ 'INFO':  2,
    \ 'DEBUG': 3,
    \ 'TRACE': 4
    \ }

" Debug categories
let s:DEBUG_CATEGORIES = {
    \ 'CORE':     'Core functionality',
    \ 'SESSION':  'Session management',
    \ 'PREVIEW':  'Markdown preview',
    \ 'SEARCH':   'Search functionality',
    \ 'CACHE':    'Cache operations',
    \ 'PARA':     'PARA system',
    \ 'UI':       'User interface',
    \ 'SYNC':     'Sync operations'
    \ }

" Initialize debug level from global setting
function! s:init_debug_level() abort
    if !exists('g:visidian_debug_level')
        let g:visidian_debug_level = 'WARN'
    endif
    if !exists('g:visidian_debug_categories')
        let g:visidian_debug_categories = ['ALL']
    endif
endfunction

" Get numeric level for given level string
function! s:get_level_number(level) abort
    return get(s:DEBUG_LEVELS, toupper(a:level), 0)
endfunction

" Check if debugging is enabled for given level and category
function! visidian#debug#is_enabled(level, category) abort
    call s:init_debug_level()
    
    " Check level
    if s:get_level_number(a:level) > s:get_level_number(g:visidian_debug_level)
        return 0
    endif
    
    " Check category
    if index(g:visidian_debug_categories, 'ALL') >= 0
        return 1
    endif
    return index(g:visidian_debug_categories, toupper(a:category)) >= 0
endfunction

" Main debug function
function! visidian#debug#log(level, category, message, ...) abort
    if !visidian#debug#is_enabled(a:level, a:category)
        return
    endif
    
    " Format timestamp
    let l:timestamp = strftime('%Y-%m-%d %H:%M:%S')
    
    " Format location if provided
    let l:location = ''
    if a:0 > 0
        let l:location = ' (' . a:1 . ')'
    endif
    
    " Format message
    let l:msg = printf('[%s] [%s] [%s]%s %s',
        \ l:timestamp,
        \ toupper(a:level),
        \ toupper(a:category),
        \ l:location,
        \ a:message)
    
    " Log message
    echomsg l:msg
    
    " For errors, also show in error format
    if toupper(a:level) ==# 'ERROR'
        echohl ErrorMsg
        echomsg l:msg
        echohl None
    endif
endfunction

" Convenience functions for different log levels
function! visidian#debug#error(category, message, ...) abort
    call call('visidian#debug#log', ['ERROR', a:category, a:message] + a:000)
endfunction

function! visidian#debug#warn(category, message, ...) abort
    call call('visidian#debug#log', ['WARN', a:category, a:message] + a:000)
endfunction

function! visidian#debug#info(category, message, ...) abort
    call call('visidian#debug#log', ['INFO', a:category, a:message] + a:000)
endfunction

function! visidian#debug#debug(category, message, ...) abort
    call call('visidian#debug#log', ['DEBUG', a:category, a:message] + a:000)
endfunction

function! visidian#debug#trace(category, message, ...) abort
    call call('visidian#debug#log', ['TRACE', a:category, a:message] + a:000)
endfunction

" Function to set debug level
function! visidian#debug#set_level(level) abort
    if !has_key(s:DEBUG_LEVELS, toupper(a:level))
        call visidian#debug#error('CORE', 'Invalid debug level: ' . a:level)
        return
    endif
    let g:visidian_debug_level = toupper(a:level)
    call visidian#debug#info('CORE', 'Debug level set to: ' . g:visidian_debug_level)
endfunction

" Function to set debug categories
function! visidian#debug#set_categories(categories) abort
    let g:visidian_debug_categories = map(copy(a:categories), 'toupper(v:val)')
    call visidian#debug#info('CORE', 'Debug categories set to: ' . string(g:visidian_debug_categories))
endfunction

" Function to list available debug levels and categories
function! visidian#debug#help() abort
    echo "Available Debug Levels (current: " . g:visidian_debug_level . "):"
    for [level, num] in items(s:DEBUG_LEVELS)
        echo printf("  %s (%d)", level, num)
    endfor
    
    echo "\nAvailable Categories (current: " . string(g:visidian_debug_categories) . "):"
    for [cat, desc] in items(s:DEBUG_CATEGORIES)
        echo printf("  %s: %s", cat, desc)
    endfor
endfunction
