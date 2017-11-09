if exists('g:autoloaded_toggle_settings')
    finish
endif
let g:autoloaded_toggle_settings = 1

com! -nargs=+ TS call s:toggle_settings(<f-args>)

" Functions {{{1
fu! s:auto_open_fold(action) abort "{{{2
    if a:action ==# 'is_active'
        return exists('s:auto_open_fold')
    elseif a:action ==# 'enable'
        let s:auto_open_fold = {
        \                        'foldenable' : &foldenable,
        \                        'foldlevel'  : &foldlevel,
        \                        'foldclose'  : &foldclose,
        \                        'foldopen'   : &foldopen,
        \                      }

        set foldenable
        set foldlevel=0   " Autofold everything by default
        set foldclose=all " Close folds if we leave them with any command
        set foldopen=all  " Open folds if we enter them with any command

        " set foldnestmax=1 " I only like to fold outer functions
    else
        let &foldenable = s:auto_open_fold.foldenable
        let &foldlevel  = s:auto_open_fold.foldlevel
        let &foldclose  = s:auto_open_fold.foldclose
        let &foldopen   = s:auto_open_fold.foldopen
        unlet! s:auto_open_fold

        " set foldnestmax=1 " I only like to fold outer functions
    endif
endfu

fu! s:cursorline(action) abort "{{{2
" 'cursorline' only in the active window and not in insert mode.
    if a:action ==# 'is_active'
        return exists('s:cursorline')
    elseif a:action ==# 'enable'
        setl cursorline
        augroup my_cursorline
            au!
            au VimEnter,WinEnter * setl cursorline
            au WinLeave          * setl nocursorline
            au InsertEnter       * setl nocursorline
            au InsertLeave       * setl cursorline
        augroup END
        let s:cursorline = 1
    else
        setl nocursorline
        sil! au! my_cursorline
        sil! aug! my_cursorline
        unlet! s:cursorline
    endif
endfu

fu! s:matchparen(enable) abort "{{{2
    let cur_win = winnr()
    if filereadable($HOME.'/.vim/after/plugin/matchparen.vim')
        so ~/.vim/after/plugin/matchparen.vim
    endif
    exe cur_win.'wincmd w'
endfu

fu! s:stl_list_position(enable) abort "{{{2
    if a:enable
        let g:my_stl_list_position = 1
    else
        let g:my_stl_list_position = 0
    endif
    redraws!
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
    \  .' :<c-u>'.cmd1
    \  .'<bar>echo '.string(
    \                         !empty(msg1) || msg1 !=# "''"
    \                       ?     msg1
    \                       :     '['.label.'] ON'
    \                      ).'<cr>'

    exe 'nno <silent> ]o'.letter
    \  .' :<c-u>'.cmd2
    \  .'<bar>echo '.string(
    \                         !empty(msg2) || msg2 !=# "''"
    \                       ?     msg2
    \                       :     '['.label.'] OFF'
    \                      ).'<cr>'

    exe 'nno <silent> co'.letter.' :<c-u>'.rhs3.'<cr>'
endfu

fu! s:virtualedit(enable) abort "{{{2
    if a:enable
        let s:ve_save = &ve
        set ve=all
        unlet! s:ve_save
    else
        let &ve = get(s:, 've_save', 'block')
    endif
    redraws!
endfu

fu! s:win_height(enable) abort "{{{2
    if a:enable
        augroup window_height
            au!
            au WinEnter * call Window_height()
        augroup END
        " We can't :echo right now, because it would cause a hit-enter prompt.
        " Probably because  `:TS` already  echo an  empty string,  which creates
        " some kind of multi-line message.
        call timer_start(0, {-> execute('echo "[window height maximized] ON"', '')})
    else
        sil! au! window_height
        sil! aug! window_height
        wincmd =
        call timer_start(0, {-> execute('echo "[window height maximized] OFF"', '')})
    endif
endfu

" Mappings {{{1
" Simple "{{{2

TS  cursorcolumn  o
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

" In   our  vimrc   we  manually   set  `g:seoul256_background`   to  choose   a
" custom  lightness.   When we  change  the  colorscheme,  from light  to  dark,
" `g:seoul256_background` has a value which will be interpreted as the desire to
" set a light colorscheme:
"
"         ~/.vim/plugged/seoul256.vim/colors/seoul256.vim
"
" This  is not  what we  want. We want  a dark  one. So, we  must make  sure the
" variable is deleted before trying to load the dark colorscheme.
TS colorscheme
                \ C
                \ colo\ seoul256-light<bar>call\ <sid>cursorline('disable')
                \ unlet!\ g:seoul256_background\|colo\ seoul256<bar>call\ <sid>cursorline('enable')
                \ ''
                \ ''
                \ get(g:,'colors_name','')=~?'light'

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

TS auto\ open\ folds
                \ f
                \ call\ <sid>auto_open_fold('enable')
                \ call\ <sid>auto_open_fold('disable')
                \ ON
                \ OFF
                \ <sid>auto_open_fold('is_active')
                " │
                " └─ We can't use a  script-local variable, because we can't
                " access it from a mapping:
                "
                "            exists('s:my_var')       ✘
                "            exists('<sid>my_var')    ✘

TS formatoptions
                \ F
                \ setl\ fo+=c
                \ setl\ fo-=c
                \ +c:\ auto-wrap\ comments\ ON
                \ -c:\ auto-wrap\ comments\ OFF
                \ index(split(&l:fo,'\\zs'),'c') != -1

" We  can't pass  `OFF` to  `:TS`, because  the message  would be  automatically
" erased when  there are several windows  in the current tabpage,  and we remove
" the autocmds.
TS window\ height\ maximized
                \ H
                \ call\ <sid>win_height(1)
                \ call\ <sid>win_height(0)
                \ ''
                \ ''
                \ exists('#window_height')

TS stl\ list\ position
                \ i
                \ call\ <sid>stl_list_position(1)
                \ call\ <sid>stl_list_position(0)
                \ ''
                \ ''
                \ get(g:,'my_stl_list_position',0)==1

TS cursorline
                \ l
                \ call\ <sid>cursorline('enable')
                \ call\ <sid>cursorline('disable')
                \ ON
                \ OFF
                \ <sid>cursorline('is_active')

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
"     nno <silent> con :<c-u>call <sid>numbers()<cr>
"
"     fu! s:numbers() abort
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
                \ call\ <sid>matchparen(1)
                \ call\ <sid>matchparen(0)
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
                \ call\ <sid>virtualedit(1)
                \ call\ <sid>virtualedit(0)
                \ ALL
                \ ø
                \ &ve==#'all'
