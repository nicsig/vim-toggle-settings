if exists('g:loaded_toggle_settings')
    finish
endif
let g:loaded_toggle_settings = 1

" Auto save {{{1

call toggle_settings#auto_save_and_read(1)

" Functions {{{1
fu! s:lazy_load_toggle_settings(key) abort "{{{2
    for lhs in [
               \ 'co',
               \ '[o',
               \ ']o',
               \ "\<plug>(lazy_load_co)",
               \ "\<plug>(lazy_load_[o)",
               \ "\<plug>(lazy_load_]o)" ]

        exe 'sil! nunmap '.lhs
    endfor

    exe 'so '.fnameescape(s:autoload_script)
    return a:key.'o'.nr2char(getchar())
endfu

" Mappings {{{1

nmap                  co                                    <plug>(lazy_load_co)
nmap <expr> <silent>  <plug>(lazy_load_co)  <sid>lazy_load_toggle_settings('c')

nmap                  [o                                    <plug>(lazy_load_[o)
nmap <expr> <silent>  <plug>(lazy_load_[o)  <sid>lazy_load_toggle_settings('[')

nmap                  ]o                                    <plug>(lazy_load_]o)
nmap <expr> <silent>  <plug>(lazy_load_]o)  <sid>lazy_load_toggle_settings(']')

" Options {{{1
" autoread {{{2

" When a file has been detected to have been changed outside of Vim and
" it has not been changed inside of Vim, automatically read it again.
" Basically, it answers 'Yes', to the question where we usually answer `Load`.
"
" When the file has been deleted this is not done.
" If the buffer-local value is set, use this command to empty it and use
" the global value again:
"
"         :set autoread<

set autoread

" Variables {{{1

let s:autoload_script = expand('<sfile>:p:h:h').'/autoload/'.expand('<sfile>:t')
