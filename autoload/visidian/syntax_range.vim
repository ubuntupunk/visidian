" SyntaxRange-like function for Visidian
function! visidian#syntax_range#include(start, end, syntax)
    let b:current_syntax = 'markdown'

    let start_pattern = escape(a:start, '\')
    let end_pattern = escape(a:end, '\')

    " Save the current position
    let save_cursor = getcurpos()

    " Search for the start pattern
    let start_line = search(start_pattern, 'w')
    while start_line > 0
        let end_line = search(end_pattern, 'W')
        if end_line == 0
            break
        endif

        " Apply the syntax highlighting
        if end_line > start_line
            let b:current_syntax = a:syntax
            execute start_line . ',' . end_line . 'syntax include @' . a:syntax . ' syntax/' . a:syntax . '.vim'
            execute start_line . ',' . end_line . 'syntax region ' . a:syntax . 'Region start="' . start_pattern . '" end="' . end_pattern . '" contains=@' . a:syntax
            unlet b:current_syntax
        endif

        " Continue searching for more blocks
        let start_line = search(start_pattern, 'W')
    endwhile

    " Restore cursor position
    call setpos('.', save_cursor)
endfunction
