" Title: Visidian.vim
" Description: A plugin for vim that imitates obsidian 
" Last Change: 2024-01-11
" Maintainer: David Robert Lewis 
" Email: ubuntupunk at gmail dot com 
" License: GPL-3.0 
" License Details: https://www.gnu.org/licenses/gpl-3.0.en.html

"Prevents the plugin from being loaded multiple times

if exists("g:loaded_visidian_vim")
   runtime! autoload/visidian.vim
 finish
endif

let g:loaded_visidian_vim = 1

"Exposes the plugins functions for use with following commands: 
command! -nargs=0 VisidianDash call visidian#dashboard()
command! -nargs=0 VisidianFile call visidian#new_md_file()
command! -nargs=0 VisidianFolder call visidian#new_folder()
command! -nargs=0 VisidianVault call visidian#create_vault()
command! -nargs=0 VisidianLink call visidian#link_notes()
command! -nargs=0 VisidianPath call visidian#set_vault_path()
command! -nargs=0 VisidianParaGen call visidian#para()
command! -nargs=0 VisidianHelp call visidian#help()
command! -nargs=0 VisidianSync call visidian#sync()
command! -nargs=0 VisidianToggleAutoSync call visidian#toggle_auto_sync()
command! -nargs=0 VisidianToggleBookmarking call visidian#toggle_bookmarking()
command! -nargs=0 VisidianTogglePreview call visidian#toggle_preview()
command! -nargs=0 VisidianToggleSidebar call visidian#toggle_sidebar()
command! -nargs=0 VisidianSearch call visidian#search()
command! -nargs=0 VisidianSort call visidian#sort()
