"Title: Visidian.vim
" Description: A plugin for vim that imitates obsidian           
" Last Change: 2024-01-11 
" Maintainer: David Robert Lewis 
" Email: ubuntupunk at gmail dot com 
" License: This program is free software. It comes without any warranty, 
" to the extent permitted by applicable law. You can redistribute it·     
" and/or modify it under the terms of the Do What The Fuck You Want To Public License,
" Version 2, as published by Sam Hocevar.    
" See http://sam.zoy.org/wtfpl/COPYING for more details.           

"Prevents the plugin from being loaded multiple times                  
if exists("g:loaded_visidian_vim")
   runtime! autoload/visidian.vim
 finish
endif
let g:loaded_visidian_vim = 1

"Exposes the plugins functions for use with following commands: 
command! -nargs=0 VisidianDashboard call visidian#dashboard()
command! -nargs=0 VisidianNewFile call visidian#new_md_file()
command! -nargs=0 VisidianNewFolder call visidian#new_folder()
command! -nargs=0 VisidianNewVault call visidian#create_vault()
command! -nargs=0 VisidianLinkNotes call visidian#link_notes()
command! -nargs=0 VisidianSetVault call visidian#set_vault_path()
command! -nargs=0 VisidianGenPara call visidian#para()
command! -nargs=0 VisidianHelp call visidian#help()
command! -nargs=0 VisidianSync call visidian#sync()
command! -nargs=0 VisidianToggleAutoSync call visidian#toggle_auto_sync()

