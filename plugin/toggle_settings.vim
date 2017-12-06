if exists('g:loaded_toggle_settings')
    finish
endif
let g:loaded_toggle_settings = 1

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
    return a:key.'o'.nr2char(getchar(),1)
endfu

" Mappings {{{1

nmap                  co                    <plug>(lazy_load_co)
nmap  <expr><silent>  <plug>(lazy_load_co)  <sid>lazy_load_toggle_settings('c')

nmap                  [o                    <plug>(lazy_load_[o)
nmap  <expr><silent>  <plug>(lazy_load_[o)  <sid>lazy_load_toggle_settings('[')

nmap                  ]o                    <plug>(lazy_load_]o)
nmap  <expr><silent>  <plug>(lazy_load_]o)  <sid>lazy_load_toggle_settings(']')

" Variables {{{1

let s:autoload_script = expand('<sfile>:p:h:h').'/autoload/'.expand('<sfile>:t')
