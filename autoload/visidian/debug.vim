" Debug levels
let s:DEBUG_LEVELS = {
    \ 'ERROR': 0,
    \ 'WARN': 1,
    \ 'INFO': 2,
    \ 'DEBUG': 3,
    \ 'TRACE': 4
    \ }

" Initialize debug level from global variable
function! s:init_debug_level()
    if !exists('g:visidian_debug_level')
        let g:visidian_debug_level = 'WARN'
    endif
    return get(s:DEBUG_LEVELS, toupper(g:visidian_debug_level), s:DEBUG_LEVELS.WARN)
endfunction

" Format debug message
function! s:format_message(level, component, msg)
    return '[' . strftime('%Y-%m-%d %H:%M:%S') . '] [' . a:level . '] [' . a:component . '] ' . a:msg
endfunction

" Log message if level is within current debug level
function! s:log_message(level, component, msg)
    let current_level = s:init_debug_level()
    let msg_level = get(s:DEBUG_LEVELS, toupper(a:level), -1)
    
    if msg_level <= current_level
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
    let g:visidian_debug_level = toupper(a:level)
    echo "Debug level set to: " . g:visidian_debug_level
endfunction

" Get current debug level
function! visidian#debug#get_level()
    return get(g:, 'visidian_debug_level', 'WARN')
endfunction
