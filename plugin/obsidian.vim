"Title: Obsidian.vim
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
if exists("g:loaded_obsidian_vim")
   runtime! autoload/obsidian.vim
 finish
endif
let g:loaded_obsidian_vim = 1

"Exposes the plugins functions for use with following commands: 
command! -nargs=0 ObsidianDashboard call obsidian#dashboard()
command! -nargs=0 ObsidianNewFile call obsidian#new_md_file()
command! -nargs=0 ObsidianNewFolder call obsidian#new_folder()
command! -nargs=0 ObsidianNewVault call obsidian#create_vault()
command! -nargs=0 ObsidianLinkNotes call obsidian#link_notes()
command! -nargs=0 ObsidianSetVault call obsidian#set_vault_path()

