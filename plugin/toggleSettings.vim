vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

const SFILE: string = expand('<sfile>:p')

# Necessary to be able to load the optional package in our vimrc with:
#
#     packadd toggleSettings
&packpath = SFILE->fnamemodify(':h:h') .. ',' .. &pp

# Don't move this autocmd in `autoload/`.{{{
#
# `MyFlags` is only fired once; when `VimEnter` itself is fired.
# Installing the autocmd *after* `VimEnter` is useless.
#}}}
augroup HoistToggleSettings | au!
    au User MyFlags statusline#hoist('global',
        \ '%{get(g:, "my_verbose_errors", v:false) ? "[Verb]" : ""}', 6, SFILE .. ':' .. expand('<sflnum>'))
    au User MyFlags statusline#hoist('buffer',
        \ '%{exists("b:auto_open_fold_mappings") ? "[AOF]" : ""}', 45, SFILE .. ':' .. expand('<sflnum>'))
    au User MyFlags statusline#hoist('buffer',
       \ '%{&l:smc > 999 ? "[smc>999]" : ""}', 46, SFILE .. ':' .. expand('<sflnum>'))
    # You could also write `split(&l:nf, ",")->index("alpha") >= 0`?{{{
    #
    # But it seems overkill here.
    # `&l:nf =~#  'alpha'` is more efficient,  and good enough; I  don't see how
    # the  test could  give a  false positive;  `&l:nf` can't  contain arbitrary
    # data.
    #}}}
    au User MyFlags statusline#hoist('buffer',
        \ '%{&l:nf =~# "alpha" ? "[nf~alpha]" : ""}', 47, SFILE .. ':' .. expand('<sflnum>'))
augroup END

com -bar -bang -nargs=1 FoldAutoOpen toggleSettings#autoOpenFold(<bang>0)
