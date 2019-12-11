if exists('g:loaded_toggle_settings')
    finish
endif
let g:loaded_toggle_settings = 1

" Don't move this autocmd in `autoload/`.{{{
"
" `MyFlags` is only fired once; when `VimEnter` itself is fired.
" Installing the autocmd *after* `VimEnter` is useless.
"}}}
augroup hoist_toggle_settings
    au!
    au User MyFlags call statusline#hoist('global', '%{get(g:, "my_verbose_errors", 0) ? "[Verb]" : ""}', 6)
    au User MyFlags call statusline#hoist('buffer', '%{exists("b:auto_open_fold_mappings") ? "[AOF]" : ""}', 45)
    " You could also write `index(split(&l:nf, ","), "alpha") >= 0`?{{{
    "
    " But it seems overkill here.
    " `&l:nf =~#  'alpha'` is more efficient,  and good enough; I  don't see how
    " the  test could  give a  false positive;  `&l:nf` can't  contain arbitrary
    " data.
    "}}}
    au User MyFlags call statusline#hoist('buffer', '%{&l:nf =~# "alpha" ? "[nf~alpha]" : ""}', 47)
augroup END

