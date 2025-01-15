" FUNCTION autoload/visidian/bookmarking.vim:

" Global variable to control bookmarking, default on
if !exists('g:visidian_bookmark_last_note')
    let g:visidian_bookmark_last_note = 1
endif

"FUNCTION: Bookmark last note
function! visidian#bookmarking#bookmark_last_note()
    if !exists('s:last_note')
        return
    endif

    " Only bookmark if the last note is within the vault
    if stridx(s:last_note, g:visidian_vault_path) == 0
        let bookmark_name = "LastVisidianNote"
        exe 'NERDTreeBookmark ' . bookmark_name . ' ' . s:last_note
        echo "Bookmarked last note: " . s:last_note
    endif
endfunction

" NOTE: You might also want to set up an autocommand to keep track of the last note whenever you open or save a markdown file:
" In vimrc or init.vim place the following:
" autocmd BufEnter,BufWritePost *.md call visidian#bookmarking#set_last_note()

" FUNCTION: set the last note
function! visidian#bookmarking#set_last_note()
    if &ft == 'markdown'
        let s:last_note = expand('%:p')
    else
        unlet! s:last_note
    endif
endfunction

" FUNCTION: toggle bookmarking
function! visidian#bookmarking#toggle_bookmarking()
    let g:visidian_bookmark_last_note = !g:visidian_bookmark_last_note
    echo "Bookmarking last note is now " . (g:visidian_bookmark_last_note ? "enabled" : "disabled")
endfunction



