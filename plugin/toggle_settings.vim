if exists('g:loaded_toggle_settings')
    finish
endif
let g:loaded_toggle_settings = 1

com! -nargs=+ TS call s:toggle_settings(<f-args>)

" Functions {{{1
fu! s:toggle_cursorline(enable) abort "{{{2
" 'cursorline' only in the active window and not in insert mode.
    if a:enable
        setl cursorline
        augroup my_cursorline
            au!
            au VimEnter,WinEnter * setl cursorline
            au WinLeave          * setl nocursorline
            au InsertEnter       * setl nocursorline
            au InsertLeave       * setl cursorline
        augroup END
        let g:my_cursorline = 1
    else
        setl nocursorline
        sil! au! my_cursorline
        sil! aug! my_cursorline
        unlet! g:my_cursorline
    endif
endfu

fu! s:toggle_folds(enable) abort "{{{2
    let keys = [
               \ 'j',
               \ 'k',
               \ 'gg',
               \ 'G',
               \ '[z',
               \ ']z',
               \ "\<c-d>",
               \ "\<c-u>",
               \ '{',
               \ '}'
               \ ]

    if a:enable
        " `<nowait>` seems to make Vim slow when we press and maintain the
        " mappings. So, don't add it.
        for l:key in keys
            exe 'nno <buffer> <silent> '.l:key.' zR'.l:key.'zMzv'
        endfor

        " `j` and `k` are special:  re-define them
        nno <buffer> <expr> <silent> j line('.') != line('$') ? 'zRjzMzv' : 'j'
        nno <buffer> <expr> <silent> k line('.') != 1         ? 'zRkzMzv' : 'k'

        norm! zMzv
    else
        for l:key in keys
            exe 'nunmap <buffer> '.l:key
        endfor
    endif
endfu

fu! s:toggle_matchparen(enable) abort "{{{2
    let cur_win = winnr()
    if filereadable($HOME.'/.vim/after/other_plugin/matchparen.vim')
        so ~/.vim/after/other_plugin/matchparen.vim
    endif
    exe cur_win.'wincmd w'
endfu

fu! s:toggle_settings(...) abort "{{{2
    if a:0 == 7
        let [ label, letter, cmd1, cmd2, msg1, msg2, test ] = a:000
        let msg1 = msg1 ==# "''" ? '' : '['.label.'] '.msg1
        let msg2 = msg2 ==# "''" ? '' : '['.label.'] '.msg2

    elseif a:0 == 2
        let [ label, letter, cmd1, cmd2, msg1, msg2, test ] =
          \ [ a:1, a:2, 'setl '.a:1, 'setl no'.a:1, '['.a:1.'] ON', '['.a:1.'] OFF', '&l:'.a:1 ]
    else
        return
    endif

    let rhs3 =      'if '.test
            \ .'<bar>    exe "'.cmd2.'"<bar>echo "'.msg2.'"'
            \ .'<bar>else'
            \ .'<bar>    exe "'.cmd1.'"<bar>echo "'.msg1.'"'
            \ .'<bar>endif'

    exe 'nno <silent> [o'.letter
    \.  ' :<c-u>'.cmd1
    \.  '<bar>echo '.string(
    \                       !empty(msg1)
    \?                          msg1
    \:                          '['.label.'] ON'
    \                      ).'<cr>'

    exe 'nno <silent> ]o'.letter
    \.  ' :<c-u>'.cmd2
    \.  '<bar>echo '.string(
    \                       !empty(msg2)
    \?                          msg2
    \:                          '['.label.'] OFF'
    \                      ).'<cr>'

    exe 'nno <silent> co'.letter.' :<c-u>'.rhs3.'<cr>'
endfu

fu! s:toggle_stl_list_position(enable) abort "{{{2
    if a:enable
        let g:my_stl_list_position = 1
    else
        let g:my_stl_list_position = 0
    endif
    redraws!
endfu

fu! s:toggle_win_height(enable) abort "{{{2
    if a:enable
        augroup window_height
            au!
            au WinEnter * call {g:vimrc_snr}resize_window()
        augroup END
    else
        sil! au! window_height
        sil! aug! window_height
        wincmd =
    endif
endfu

" Mappings {{{1
" Simple "{{{2

TS  cursorcolumn  L
TS  cursorline    l
TS  hlsearch      h
TS  list          I
TS  showcmd       W
TS  spell         s
TS  wrap          w

" Complex {{{2

TS showbreak
                \ b
                \ setl\ showbreak=↪
                \ setl\ showbreak=
                \ ON
                \ OFF
                \ !empty(&sbr)

TS colorscheme
                \ C
                \ colo\ my_seoul_light<bar>call\ <sid>toggle_cursorline(0)
                \ colo\ my_seoul_dark<bar>call\ <sid>toggle_cursorline(1)
                \ light
                \ dark
                \ g:colors_name=~?'light'

TS conceal
                \ c
                \ setl\ cole=2
                \ setl\ cole=3
                \ Partial
                \ Full
                \ &l:cole==2

TS diff
                \ d
                \ diffthis
                \ diffoff
                \ ON
                \ OFF
                \ &l:diff

TS formatoptions
                \ f
                \ setl\ fo+=c
                \ setl\ fo-=c
                \ +c:\ auto-wrap\ comments\ ON
                \ -c:\ auto-wrap\ comments\ OFF
                \ index(split(&l:fo,'\\zs'),'c') != -1

TS auto\ open\ folds
                \ F
                \ call\ <sid>toggle_folds(1)
                \ call\ <sid>toggle_folds(0)
                \ ON
                \ OFF
                \ !empty(maparg('gg','n'))

TS window\ height\ maximized
                \ H
                \ call\ <sid>toggle_win_height(1)
                \ call\ <sid>toggle_win_height(0)
                \ ON
                \ OFF
                \ exists('#window_height')

TS stl\ list\ position
                \ i
                \ call\ <sid>toggle_stl_list_position(1)
                \ call\ <sid>toggle_stl_list_position(0)
                \ ''
                \ ''
                \ get(g:,'my_stl_list_position',0)==1

TS cursorline
                \ l
                \ call\ <sid>toggle_cursorline(1)
                \ call\ <sid>toggle_cursorline(0)
                \ ON
                \ OFF
                \ exists('g:my_cursorline')

" NOTE: We can't use a script-local variable, because we can't access it from
" a mapping:
"
"         exists('s:my_cursorline')       ✘
"         exists('<sid>my_cursorline')    ✘


TS number
                \ n
                \ setl\ number\ relativenumber
                \ setl\ nonumber\ norelativenumber
                \ ''
                \ ''
                \ &l:nu

" Alternative:{{{
" The following mapping/function allows to cycle through 3 states:
"
"     1. nonumber + norelativenumber
"     2. number   +   relativenumber
"     3. number   + norelativenumber
"
"     nno <silent> con :<c-u>call <sid>toggle_numbers()<cr>
"
"     fu! s:toggle_numbers() abort
"         " The key '01' (state) is not necessary because no command in the dictionary
"         " brings us to it.
"         " However, if we got in this state by accident, hitting the mapping would raise
"         " an error (E716: Key not present in Dictionary).
"         " So, we include it, and give it a value which brings us to state '11'.
"
"         exe {
"           \   '00' : 'setl nu | setl rnu',
"           \   '11' : 'setl nornu',
"           \   '01' : 'setl nonu',
"           \   '10' : 'setl nonu | setl nornu',
"           \ }[&l:nu.&l:rnu]
"     endfu
"}}}

TS nrformats
                \ N
                \ setl\ nf+=alpha
                \ setl\ nf-=alpha
                \ +alpha
                \ -alpha
                \ index(split(&l:nf,','),'alpha') != -1

TS MatchParen
                \ p
                \ call\ <sid>toggle_matchparen(1)
                \ call\ <sid>toggle_matchparen(0)
                \ ON
                \ OFF
                \ exists('g:loaded_matchparen')

TS spelllang
                \ S
                \ setl\ spl=fr
                \ setl\ spl=en
                \ FR
                \ EN
                \ &l:spl==#'fr'

TS fold\ title
                \ t
                \ let\ b:my_title_full=1\|redraw!
                \ let\ b:my_title_full=0\|redraw!
                \ full
                \ short
                \ get(b:,'my_title_full',0)

TS virtualedit
                \ v
                \ set\ ve=all\|redraws!
                \ set\ ve=\|redraws!
                \ ALL
                \ ø
                \ !empty(&ve)

