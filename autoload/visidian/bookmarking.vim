" FUNCTION autoload/visidian/bookmarking.vim:


"FUNCTION: Bookmark Last Note"
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

"FIXME: Copied from visidian.vim, should these rather be here?
" FUNCTION: set the last note
"function! visidian#bookmarking#set_last_note()
"    if &ft == 'markdown'
"        let s:last_note = expand('%:p')
"    else
"        unlet! s:last_note
"    endif
"endfunction

"FUNCTION: toggle bookmarking
"function! visidian#bookmarking#toggle_bookmarking()
"    let g:visidian_bookmark_last_note = !g:visidian_bookmark_last_note
"    echo "Bookmarking last note is now " . (g:visidian_bookmark_last_note ? "enabled" : "disabled")
"endfunction


