" autoload/visidian/bookmarking.vim:

" Global variable to control bookmarking, default on
if !exists('g:visidian_bookmark_last_note')
    let g:visidian_bookmark_last_note = 1
    call visidian#debug#debug('CORE', 'Initialized bookmarking system')
endif

"FUNCTION: Bookmark last note
function! visidian#bookmarking#bookmark_last_note()
    if !exists('s:last_note')
        call visidian#debug#warn('CORE', 'No last note to bookmark')
        return
    endif

    " Only bookmark if the last note is within the vault
    if stridx(s:last_note, g:visidian_vault_path) == 0
        let bookmark_name = "LastVisidianNote"
        try
            exe 'NERDTreeBookmark ' . bookmark_name . ' ' . s:last_note
            call visidian#debug#info('CORE', 'Bookmarked last note: ' . s:last_note)
            echo "Bookmarked last note: " . s:last_note
        catch
            call visidian#debug#error('CORE', 'Failed to create bookmark: ' . v:exception)
            echohl ErrorMsg
            echo "Failed to create bookmark: " . v:exception
            echohl None
        endtry
    else
        call visidian#debug#warn('CORE', 'Last note not in vault: ' . s:last_note)
    endif
endfunction

" NOTE: You might also want to set up an autocommand to keep track of the last note whenever you open or save a markdown file:
" In vimrc or init.vim place the following:
" autocmd BufEnter,BufWritePost *.md call visidian#bookmarking#set_last_note()

" FUNCTION: set the last note
function! visidian#bookmarking#set_last_note()
    if &ft == 'markdown'
        let s:last_note = expand('%:p')
        call visidian#debug#debug('CORE', 'Set last note: ' . s:last_note)
    else
        unlet! s:last_note
        call visidian#debug#debug('CORE', 'Cleared last note')
    endif
endfunction

" FUNCTION: toggle bookmarking
function! visidian#bookmarking#toggle_bookmarking()
    let g:visidian_bookmark_last_note = !g:visidian_bookmark_last_note
    call visidian#debug#info('CORE', 'Bookmarking ' . (g:visidian_bookmark_last_note ? 'enabled' : 'disabled'))
    echo "Bookmarking last note is now " . (g:visidian_bookmark_last_note ? "enabled" : "disabled")
endfunction
