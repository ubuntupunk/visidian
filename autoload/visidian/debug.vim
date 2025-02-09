" Debug levels
let s:DEBUG_LEVELS = {
    \ 'ERROR': 0,
    \ 'WARN': 1,
    \ 'INFO': 2,
    \ 'DEBUG': 3,
    \ 'TRACE': 4
    \ }

" Debug categories
let s:DEBUG_CATEGORIES = [
    \ 'ALL',
    \ 'CORE',
    \ 'SESSION',
    \ 'PREVIEW',
    \ 'SEARCH',
    \ 'CACHE',
    \ 'PARA',
    \ 'UI',
    \ 'SYNC',
    \ 'BOOKMARKS',
    \ 'LINK',
    \ 'NOTES',
    \ ]

" Initialize debug level from global variable
function! s:init_debug_level()
    if !exists('g:visidian_debug_level')
        let g:visidian_debug_level = 'WARN'
    endif
    return get(s:DEBUG_LEVELS, toupper(g:visidian_debug_level), s:DEBUG_LEVELS.WARN)
endfunction

" Initialize debug categories from global variable
function! s:init_debug_categories()
    if !exists('g:visidian_debug_categories')
        let g:visidian_debug_categories = ['ALL']
    endif
    return g:visidian_debug_categories
endfunction

" Format debug message
function! s:format_message(level, component, msg)
    return '[' . strftime('%Y-%m-%d %H:%M:%S') . '] [' . a:level . '] [' . a:component . '] ' . a:msg
endfunction

" Log message if level is within current debug level
function! s:log_message(level, component, msg)
    let current_level = s:init_debug_level()
    let msg_level = get(s:DEBUG_LEVELS, toupper(a:level), -1)
    let categories = s:init_debug_categories()
    
    if msg_level <= current_level && (index(categories, 'ALL') >= 0 || index(categories, toupper(a:component)) >= 0)
        let formatted = s:format_message(a:level, a:component, a:msg)
        call s:write_to_messages(formatted)
    endif
endfunction

" Write to vim messages
function! s:write_to_messages(msg)
    if exists('*execute')
        silent! execute "messages add=" . string(a:msg)
    else
        echomsg a:msg
    endif
endfunction

" Public debug functions
function! visidian#debug#error(component, msg)
    call s:log_message('ERROR', a:component, a:msg)
endfunction

function! visidian#debug#warn(component, msg)
    call s:log_message('WARN', a:component, a:msg)
endfunction

function! visidian#debug#info(component, msg)
    call s:log_message('INFO', a:component, a:msg)
endfunction

function! visidian#debug#debug(component, msg)
    call s:log_message('DEBUG', a:component, a:msg)
endfunction

function! visidian#debug#trace(component, msg)
    call s:log_message('TRACE', a:component, a:msg)
endfunction

" Set debug level
function! visidian#debug#set_level(level)
    let level = toupper(a:level)
    if has_key(s:DEBUG_LEVELS, level)
        let g:visidian_debug_level = level
        call s:log_message('INFO', 'DEBUG', 'Debug level set to: ' . level)
    else
        call s:log_message('ERROR', 'DEBUG', 'Invalid debug level: ' . a:level)
    endif
endfunction

" Set debug categories
function! visidian#debug#set_categories(categories)
    let categories = map(copy(a:categories), 'toupper(v:val)')
    let invalid = filter(copy(categories), 'index(s:DEBUG_CATEGORIES, v:val) < 0')
    
    if !empty(invalid)
        call s:log_message('ERROR', 'DEBUG', 'Invalid debug categories: ' . join(invalid, ', '))
        return
    endif
    
    let g:visidian_debug_categories = categories
    call s:log_message('INFO', 'DEBUG', 'Debug categories set to: ' . join(categories, ', '))
endfunction
