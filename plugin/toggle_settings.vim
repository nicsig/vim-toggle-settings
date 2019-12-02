if exists('g:loaded_toggle_settings')
    finish
endif
let g:loaded_toggle_settings = 1

" Don't move this autocmd in `autoload/`.{{{
"
" `MyFlags` is only fired once; when `VimEnter` itself is fired.
" Installing the autocmd *after* `VimEnter` is useless.
"}}}
augroup hoist_aof
    au!
    au User MyFlags call statusline#hoist('buffer', '%{exists("b:auto_open_fold_mappings") ? "[AOF]" : ""}', 45)
augroup END

