if !exists('g:visidian_loaded_syntax_range')
    let g:visidian_loaded_syntax_range = 1

    " Only apply if we're in a Markdown file
    if &filetype == 'markdown'
        " Syntax highlighting for code blocks in markdown
        call visidian#syntax_range#include('```vim', '```', 'vim')
        call visidian#syntax_range#include('```python', '```', 'python')
        call visidian#syntax_range#include('```c', '```', 'c')
        call visidian#syntax_range#include('```cpp', '```', 'cpp')
        call visidian#syntax_range#include('```haskell', '```', 'haskell')
        call visidian#syntax_range#include('```ocaml', '```', 'ocaml')
        call visidian#syntax_range#include('```ruby', '```', 'ruby')
        call visidian#syntax_range#include('```rust', '```', 'rust')
        
        " LaTeX support for inline and display math
        call visidian#syntax_range#include('\$\$', '\$\$', 'tex')
        call visidian#syntax_range#include('\$', '\$', 'tex')
    endif
endif

" Check if the syntax has already been loaded
if exists('g:visidian_loaded_todo_syntax')
    finish
endif
let g:visidian_loaded_todo_syntax = 1

" Define TODO keyword syntax
syn match visidian_todo_key /\[\zs[^]]*\ze\]/
hi def link visidian_todo_key Identifier

" Define where TODO keywords can appear; for simplicity, we'll assume they're 
" only at the beginning of lines in markdown or within code blocks for now
syn match visidian_todo_keyword /TODO\|DONE\|FIXME\|XXX/ 
    \ containedin=ALL
    \ nextgroup=visidian_todo_item skipwhite 
syn match visidian_todo_item /.*$/ 
    \ contained containedin=visidian_todo_keyword

" Set up highlighting for TODO keywords
hi def link visidian_todo_keyword Todo
hi def link visidian_todo_item Normal

" Function to handle custom TODO keywords if needed
function! s:ReadTodoKeywords(keywords)
    let l:default_group = 'Todo'
    for keyword in a:keywords
        if keyword == '|'
            let l:default_group = 'Question'
            continue
        endif
        
        " Create a syntax match for each keyword
        exe 'syn match visidian_todo_keyword_' . keyword . ' /\<' . keyword . '\>/ containedin=ALL'
        " Link to a highlight group, default to 'Todo' unless changed by '|'
        exe 'hi def link visidian_todo_keyword_' . keyword . ' ' . l:default_group
    endfor
endfunction

" Example usage with custom keywords
let g:visidian_todo_keywords = ['TODO', 'DONE', 'FIXME', 'XXX', '|', 'NOTE']
call s:ReadTodoKeywords(g:visidian_todo_keywords)


" Emoji tickbox support for TODO lists
syn match visidian_todo_checkbox '\v(☐|☑|✘)'
hi def link visidian_todo_checkbox Special

" Match the TODO items with check boxes
syn match visidian_todo_item_with_checkbox '\v(☐|☑|✘)\s+.*$'
    \ containedin=ALL
hi def link visidian_todo_item_with_checkbox Normal

"FOLDS SECTION

" Define fold markers for headings
syn region markdownFold start="^\s*#" end="^\ze\s*\(#\)\@!" transparent fold keepend

" Define fold for TODO items, assuming they start with a checkbox or TODO keyword
syn region todoFold start="\v(☐|☑|✘|TODO|DONE|FIXME|XXX)\s+" end="\n\ze\n" transparent fold keepend

setlocal foldmethod=syntax
setlocal foldlevel=1  " Start with all folds open

