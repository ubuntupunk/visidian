" Detect markdown files
autocmd BufNewFile,BufRead *.md,*.markdown,*.mkd,*.mkdn,*.mdwn,*.mdown,*.mdtxt,*.mdtext,*.text setfiletype markdown

" Ensure modeline is processed after filetype is set
autocmd BufRead,BufNewFile * if &filetype == '' && expand('%:e') =~? '^md\|markdown$' | setfiletype markdown | endif
