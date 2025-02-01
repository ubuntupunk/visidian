" Title: Visidian.vim
" Description: A plugin for vim that imitates obsidian 
" Last Change: 2024-01-11
" Maintainer: David Robert Lewis 
" Email: ubuntupunk at gmail dot com 
" License: GPL-3.0 
" License Details: https://www.gnu.org/licenses/gpl-3.0.en.html

" Prevents the plugin from being loaded multiple times
if exists("g:loaded_visidian_vim")
    finish
endif

let g:loaded_visidian_vim = 1

" Set up session options
set sessionoptions=blank,buffers,curdir,folds,help,tabpages,winsize,terminal

" Load autoload functions
runtime! autoload/visidian.vim

" Exposes the plugins functions for use with following commands: 
command! -nargs=0 VisidianDash call visidian#dashboard()
command! -nargs=0 VisidianFile call visidian#new_md_file()
command! -nargs=0 VisidianFolder call visidian#new_folder()
command! -nargs=0 VisidianVault call visidian#create_vault()
command! -nargs=0 VisidianLink call visidian#link_notes()
command! -nargs=0 VisidianParaGen call visidian#create_para_folders()
command! -nargs=0 VisidianHelp call visidian#help()
command! -nargs=0 VisidianSync call visidian#sync()
command! -nargs=0 VisidianToggleAutoSync call visidian#toggle_auto_sync()
command! -nargs=0 VisidianTogglePreview call visidian#toggle_preview()
command! -nargs=0 VisidianToggleSidebar call visidian#toggle_sidebar()
command! -nargs=0 VisidianSearch call visidian#search()
command! -nargs=0 VisidianSort call visidian#sort()
command! -nargs=0 VisidianMenu call visidian#menu()

" Session management commands
command! -nargs=0 VisidianSaveSession call visidian#save_session()
command! -nargs=0 VisidianLoadSession call visidian#load_session()
command! -nargs=0 VisidianListSessions call visidian#list_sessions()
command! -nargs=0 VisidianChooseSession call visidian#choose_session()
command! -nargs=0 VisidianClearSessions call visidian#clear_sessions()

" Generate & Browse Ctags
command! -nargs=0 VisidianGenerateTags call VisidianGenerateTags()
command! -nargs=0 VisidianBrowseTags call VisidianBrowseTags()
