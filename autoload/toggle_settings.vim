if exists('g:autoloaded_toggle_settings')
    finish
endif
let g:autoloaded_toggle_settings = 1

" Don't forget to properly handle repeated (dis)activations. {{{
" Necessary when you save/restore a state with a custom variable.
"
" When you  write a function  to activate/disactivate/toggle some state,  do NOT
" assume it will only be used for repeated toggling.
" It  can also  be used  for (accidental)  repeated activation,  or (accidental)
" repeated disactivation.
"
" If the function doesn't save/restore a  state using a custom variable, there's
" no issue (ex: `s:cursorline()`).  But  if it does (ex: `s:virtualedit()`), and
" you don't handle repeated (dis)activations, it can lead to errors.
"
" For example,  if you transit to  the same state  twice, the 1st time,  it will
" work as expected: the  function will save the original state,  A, then put you
" in the new state B.
" But the 2nd time, the function will blindly save B, as if it was A.
" So, when you will invoke it to restore A, you will, in effect, restore B.
"}}}
" What should you avoid?{{{
"
" NEVER write this:
"
"            ┌ boolean argument:
"            │
"            │      • when it's 1 it means we want to enable  some state
"            │      • "         0                     disable "
"            │
"         if a:enable                       ✘
"             let s:save = ...
"                 │
"                 └ save current state for future restoration
"             ...
"         else                              ✘
"             ...
"         endif
"
" Instead:
"
"         if a:enable && is_disabled        ✔
"             let s:save = ...
"             ...
"         elseif a:disable && is_enabled    ✔
"             ...
"         endif
"}}}
" Which functions are concerned?{{{
"
" All functions make  you transit to a new known  state (are there exceptions?).
" But some of them do it from a  known state, while others do it from an UNKNOWN
" one.  The current issue concerns the  latter, because when you transit from an
" unknown state, you have to save it first for the future restoration. You don't
" need to do that when you know it in advance.
"}}}

" Autocmds {{{1

augroup hl_yanked_text
    au!
    au TextYankPost * if s:toggle_hl_yanked_text('is_active') | call s:hl_yanked_text() | endif
augroup END

" Functions {{{1
fu! s:auto_open_fold(action) abort "{{{2
    if a:action is# 'is_active'
        return exists('s:fold_options_save')
    elseif a:action is# 'enable' && !exists('s:fold_options_save')
        let s:fold_options_save = {
        \                           'close'  : &foldclose,
        \                           'open'   : &foldopen,
        \                           'enable' : &foldenable,
        \                           'level'  : &foldlevel,
        \                         }

        " Consider setting 'foldnestmax' if you use 'indent'/'syntax' as a folding method.{{{
        "
        " If you set the local value of  'fdm' to 'indent' or 'syntax', Vim will
        " automatically fold the buffer according to its indentation / syntax.
        "
        " It can lead to deeply nested folds. This can be annoying when you have
        " to open  a lot of  folds to  read the contents  of a line.
        "
        " One way to tackle this issue  is to reduce the value of 'foldnestmax'.
        " By default  it's 20 (which is  the deepest level of  nested folds that
        " Vim can produce with these 2 methods  anyway). If you set it to 1, Vim
        " will only produce folds for the outermost blocks (functions/methods).
        "}}}
        set foldclose=all " close a fold if we leave it with any command
        set foldopen=all  " open  a fold if we enter it with any command
        set foldenable
        set foldlevel=0   " close all folds by default
    elseif a:action is# 'disable' && exists('s:fold_options_save')
        for op in keys(s:fold_options_save)
            exe 'let &fold'.op.' = s:fold_options_save.'.op
        endfor
        norm! zMzv
        unlet! s:fold_options_save
    endif
endfu

fu! s:change_cursor_color(color) abort "{{{2
    " Why?{{{
    "
    " We're going to execute a `$ printf` command, via `:!`.
    "
    " It may contain a `#` character (prefix in hex code).
    " On Vim's command-line, this character is automatically expanded
    " in the name of the alternate file.
    "
    " We don't want that.
    "}}}
    let color = escape(a:color, '#')

    " The general syntax to set an xterm parameter is:{{{
    "
    "         ESC ] Ps;Pt ST
    "               └┤ └┤ └┤
    "                │  │  └ \007; \0 = octal base (what's the meaning of ST?)
    "                │  │
    "                │  └ a text parameter composed of printable characters
    "                │
    "                └ a single (usually optional) numeric parameter,
    "                  composed of one or more digits
    "
    " http://pod.tst.eu/http://cvs.schmorp.de/rxvt-unicode/doc/rxvt.7.pod#Definitions
    " http://pod.tst.eu/http://cvs.schmorp.de/rxvt-unicode/doc/rxvt.7.pod#XTerm_Operating_System_Commands
    "
    " Here, we want to set the color of the cursor to #373b41.
    " The latter must take the place  of the `Pt` parameter (the color could
    " be a  name instead of a  hex number, so  it fits the description  of a
    " TEXT parameter):
    "
    "         → Ps = 12
    "           Change colour of text cursor foreground to Pt
    "}}}
    let seq = '\033]12;'.color.'\007'

    " FIXME: Doesn't work in Neovim.

    " TODO: How to use `system()` instead of `:!`?
    " We wouldn't need to escape `#`...

    " FIXME: After changing the colorscheme, the cursor quickly blinks at random moments.
    " It's subtle but distracting.
    " I think it's because of this sequence...
    exe 'sil !printf '.string(seq)
endfu

fu! s:colorscheme(is_light) abort "{{{2
    if a:is_light
        colo seoul256-light
        call s:cursorline(0)
        call s:change_cursor_color('#373b41')
    else
        " Why unletting `g:seoul256_background`?{{{
        "
        " When Vim starts, we call `colorscheme#set()` from our vimrc.
        " This function is defined in `~/.vim/autoload/colorscheme.vim`.
        " It manually set `g:seoul256_background` to choose a custom lightness.
        "
        " When   we    change   the    colorscheme,   from   light    to   dark,
        " `g:seoul256_background` has a value which will be interpreted as the
        " desire to set a light colorscheme:
        "
        "         ~/.vim/plugged/seoul256.vim/colors/seoul256.vim
        "
        " This is not what we want.
        " We want a dark one.
        " So, we  must make sure the  variable is deleted before  trying to load
        " the dark colorscheme.
        "}}}
        unlet! g:seoul256_background
        colo seoul256
        " We  enable 'cul'  in  a  dark colorscheme,  but  it  can be  extremely
        " cpu-consuming when  you move  horizontally (j,  k, w,  b, e,  ...) and
        " 'showcmd' is enabled.
        call s:cursorline(1)
        call s:change_cursor_color('#9a7372')
    endif
endfu

fu! s:conceallevel(is_fwd, ...) abort "{{{2
    if a:0
        " Why toggling between `0` and `2`, instead of `0` and `3` like everywhere else?{{{
        "
        " In a markdown file, we want to see `cchar`.
        " It's useful to see a marker denoting a concealed answer to a question,
        " for example. It could also be useful to pretty-print some logical/math
        " symbols.
        "}}}
        if &ft is# 'markdown'
            let &l:cole = &l:cole ==# 2 ? 0 : 2
        else
            let &l:cole = &l:cole ==# a:1 ? a:2 : a:1
        endif
        echo '[conceallevel] '.&l:cole
        return
    endif

    let new_val = a:is_fwd
              \ ?     (&l:cole + 1)%(3+1)
              \ :     3 - (3 - &l:cole + 1)%(3+1)

    " We are not interested in level 1.
    " The 3 other levels are enough. If I want to see:
    "
    "     • everything = 0
    "
    "     • what is useful = 2
    "       has a replacement character: `cchar`, {'conceal': 'x'}
    "
    "     • nothing = 3
    if new_val ==# 1
        let new_val = a:is_fwd ? 2 : 0
    endif

    let &l:cole = new_val
    echo '[conceallevel] '.&l:cole
endfu

fu! s:cursorline(enable) abort "{{{2
    " 'cursorline' only in the active window and not in insert mode.
    if a:enable
        setl cursorline
        augroup my_cursorline
            au!
            " Why `BufWinEnter` and `BufWinLeave`?{{{
            "
            " If you load  another buffer in the current  window, `WinLeave` and
            " `WinEnter` are not fired.
            " It may happen, for example, when  you move in the quickfix list by
            " pressing `]q`.
            "}}}
            au VimEnter,BufWinEnter,WinEnter * setl cursorline
            au BufWinLeave,WinLeave          * setl nocursorline
            au InsertEnter                   * setl nocursorline
            au InsertLeave                   * setl cursorline
        augroup END
    else
        sil! au! my_cursorline
        sil! aug! my_cursorline
        setl nocursorline
    endif
endfu

fu! s:edit_help_file(allow) "{{{2
    if &ft isnot# 'help'
        return
    endif
    if a:allow && !empty(maparg('q', 'n', 0, 1))
        nno  <buffer><nowait><silent>  <cr>  80<bar>

        let keys = ['p', 'q' , 'u']
        for a_key in keys
            exe 'sil unmap <buffer> '.a_key
        endfor

        for pat in map(keys, {i,v ->  '|\s*exe\s*''[nx]unmap\s*<buffer>\s*'.v."'"})
            let b:undo_ftplugin = substitute(b:undo_ftplugin, pat, '', 'g')
        endfor

        setl modifiable noreadonly bt=
        echo 'you CAN edit the file'

    elseif !a:allow && empty(maparg('q', 'n', 0, 1))
        " reload ftplugin
        edit
        setl nomodifiable readonly bt=help
        echo 'you can NOT edit the file'
    endif
endfu

fu! s:formatprg(scope) abort "{{{2
    if a:scope is# 'global' && (!exists('s:local_fp_save') || !has_key(s:local_fp_save, bufnr('%')))
        if !exists('s:local_fp_save')
            let s:local_fp_save = {}
        endif
        " use a dictionary to  save the local value of 'fp'  in any buffer where
        " we use our mappings to toggle the latter
        let s:local_fp_save[bufnr('%')] = &l:fp
        set fp<
    elseif a:scope is# 'local' && exists('s:local_fp_save') && has_key(s:local_fp_save, bufnr('%'))
        " `js-beautify` is a formatting tool for js, html, css.
        "
        " Installation:
        "
        "         sudo npm -g install js-beautify
        "
        " Documentation:
        "
        "         https://github.com/beautify-web/js-beautify
        "
        " The tool has  many options, you can use the  ones you find interesting
        " in the value of 'fp'.
        let &l:fp = get(s:local_fp_save, bufnr('%'), &l:fp)
        unlet! s:local_fp_save[bufnr('%')]
    endif
    echo '[formatprg] '.(!empty(&l:fp) ? &l:fp : &g:fp)
endfu

fu! s:hl_yanked_text() abort "{{{2
    try
        "  ┌ don't highlight anything if we didn't copy anything
        "  │
        "  │                              ┌ don't highlight anything if Vim has copied
        "  │                              │ the visual selection in `*` after we leave
        "  │                              │ visual mode
        "  ├─────────────────────────┐    ├─────────────────────┐
        if v:event.operator isnot# 'y' || v:event.regname is# '*'
            return
        endif

        let text = v:event.regcontents
        let type = v:event.regtype
        if type is# 'v'
            let text = join(v:event.regcontents, "\n")
            let pat = '\%'.line('.').'l\%'.virtcol('.').'v\_.\{'.strchars(text, 1).'}'
        elseif type is# 'V'
            let pat = '\%'.line('.').'l\_.*\%'.(line('.')+len(text)-1).'l'
        elseif type =~# "\<c-v>".'\d\+'
            let width = matchstr(type, "\<c-v>".'\zs\d\+')
            let [line, vcol] = [line('.'), virtcol('.')]
            let pat = join(map(text, {i -> '\%'.(line+i).'l\%'.vcol.'v.\{'.width.'}'}), '\|')
        endif

        let id = matchadd('IncSearch', pat, 0, -1)
        call timer_start(250, {-> exists('id') ? matchdelete(id) : ''})
    catch
        return lg#catch_error()
    endtry
endfu

fu! s:lightness(more, ...) abort "{{{2
    " toggle between 2 predefined levels of lightness
    if a:0
        if &bg is# 'light'
            let g:seoul256_light_background =
                \ get(g:, 'seoul256_light_background', 253) ==# a:1 ? a:2 : a:1
            colo seoul256-light
            let level = get(g:, 'seoul256_light_background', 253) - 252 + 1
        else
            let g:seoul256_background =
                \ get(g:, 'seoul256_background', 237) ==# 233 ? 237 : 233
            colo seoul256
            let level = get(g:, 'seoul256_background', 237) - 233 + 1
        endif

        call timer_start(0, {-> execute('echo "[lightness]"'.level, '')})
        return
    endif

    " increase or decrease the lightness
    if &bg is# 'light'
        " We need to make `g:seoul256_light_background` cycle through [252, 256].

        " How to make a number `n` cycle through [a, a+1, ..., a+p] ?{{{
        "                                                   ^
        "                                                   `n` will always be somewhere in the middle
        "
        " Let's simplify the pb, and cycle from 0 up to `p`. Solution:
        "
        "         • initialize `n` to 0
        "         • use the formula  (n+1)%(p+1)  to update `n`
        "                             ├─┘ ├────┘
        "                             │   └ but don't go above `p`
        "                             │     read this as:  “p+1 is off-limit”
        "                             │
        "                             └ increment
        "
        " To use this solution, we need to find a link between the problem we've
        " just solved and our original problem.
        " In the latter, what cycles between 0 and `p`?
        "
        "         the distance between `a` and `n`
        "
        " Updated_solution:
        "                              before, it was `0`
        "                              v
        "         • initialize `n` to `a`
        "
        "         • use  (d+1)%(p+1)  to update the DISTANCE between `a` and `n`
        "                 ^                                           ^
        "                 before, it was `n`                          before, it was `0`
        "
        " Let's formalize the last sentence, using  `d1`, `d2`, `n1` and `n2` to
        " stand for the old / new distances and the old / new values of `n`:
        "
        "     ⇔    d2    = (  d1 + 1)%(p+1)
        "     ⇔ n2 - a   = (n1-a + 1)%(p+1)
        "
        "                  ┌ final formula
        "                  ├────────────────┐
        "     ⇔ n2       = (n1-a +1)%(p+1) +a
        "                   ├─────┘ ├────┘ ├┘
        "                   │       │      └ we want the distance from 0, not from `a`, so add `a`
        "                   │       └ but don't go too far
        "                   └ move away (+1) from `a` (n1-a)
    "}}}
        " How to make a number cycle through [a+p, a+p-1, ..., a] ?{{{
        "
        " We want to cycle from `a+p` down to `a`.
        "
        "         • initialize `n` to `a+p`
        "         • use the formula  (d+1)%(p+1)  to update the DISTANCE between `n` and `a+p`
        "
        " Formalization:
        "
        "            d2   = (    d1   + 1)%(p+1)
        "      ⇔ a+p - n2 = (a+p - n1 + 1)%(p+1)
        "
        "                     ┌ final formula
        "                     ├───────────────────────┐
        "      ⇔         n2 = a+p - (a+p - n1 +1)%(p+1)
        "                     ├─┘    ├─────────┘ ├────┘
        "                     │      │           └ but don't go too far
        "                     │      │             read this as:  “a+p is off-limit”
        "                     │      │
        "                     │      └ move away (+1) from `a+p` (a+p - n1)
        "                     │
        "                     └ we want the distance from 0, not from `a+p`, so add `a+p`
        "}}}

        "   ┌ value to be used the NEXT time we execute `:colo seoul256-light`
        "   │
        let g:seoul256_light_background = get(g:, 'seoul256_light_background', 253)

        " update `g:seoul256_light_background`
        let g:seoul256_light_background = a:more
        \ ?       (g:seoul256_light_background - 252 + 1)%(4+1) + 252
        \ :       256 - (256 - g:seoul256_light_background +1)%(4+1)

        " update colorscheme
        colo seoul256-light
        " get info to display in a message
        let level = g:seoul256_light_background - 252 + 1

    else
        " We need to make `g:seoul256_background` cycle through [233, 239].

        "   ┌ value to be used the NEXT time we execute `:colo seoul256`
        "   │
        let g:seoul256_background = get(g:, 'seoul256_background', 237)

        let g:seoul256_background = a:more
        \ ?       (g:seoul256_background - 233 + 1)%(6+1) + 233
        \ :       239 - (239 - g:seoul256_background +1)%(6+1)

        colo seoul256
        let level = g:seoul256_background - 233 + 1
    endif

    call timer_start(0, {-> execute('echo "[lightness]"'.level, '')})
    return ''
endfu

fu! s:matchparen(enable) abort "{{{2
    if empty(globpath(&rtp, 'plugin/matchparen_toggle.vim', 0, 1, 1))
        echo printf('no  %s  file was found in the runtimepath', 'plugin/matchparen.vim')
        return
    endif
    let cur_win = winnr()
    if a:enable && !exists('g:loaded_matchparen') || !a:enable && exists('g:loaded_matchparen')
        runtime! plugin/matchparen_toggle.vim
    endif
    exe cur_win.'wincmd w'
    echo '[matchparen] '.(exists('g:loaded_matchparen') ? 'ON' : 'OFF')
endfu

fu! s:stl_list_position(is_fwd, ...) abort "{{{2
    if a:0
        let g:my_stl_list_position = get(g:, 'my_stl_list_position', 0) ==# 0
                                 \ ?     (empty(getqflist()) ? 2 : 1)
                                 \ :     0
        return
    endif

    let g:my_stl_list_position = get(g:, 'my_stl_list_position', 0)
    let g:my_stl_list_position = a:is_fwd
    \ ?               (g:my_stl_list_position + 1)%(2+1)
    \ :               2 - (2 - g:my_stl_list_position + 1)%(2+1)

    " necessary to update the list position item immediately
    redraws
endfu

fu! s:toggle_hl_yanked_text(action) abort "{{{2
    if a:action is# 'is_active'
        return exists('s:hl_yanked_text')
    elseif a:action is# 'enable' && !exists('s:hl_yanked_text')
        let s:hl_yanked_text = 1
    elseif a:action is# 'disable' && exists('s:hl_yanked_text')
        unlet! s:hl_yanked_text
    endif
endfu

fu! s:toggle_settings(...) abort "{{{2
    if a:0 ==# 7
        let [label, letter, cmd1, cmd2, msg1, msg2, test] = a:000
        let msg1 = '['.label.'] '.msg1
        let msg2 = '['.label.'] '.msg2

    elseif a:0 ==# 5
        let [label, letter, cmd1, cmd2, test] = a:000

        let rhs3 = '     if '.test
            \ .'<bar>    exe '.string(cmd2)
            \ .'<bar>else'
            \ .'<bar>    exe '.string(cmd1)
            \ .'<bar>endif'

        exe 'nno  <silent><unique>  [o'.letter.'  :<c-u>'.cmd1.'<cr>'
        exe 'nno  <silent><unique>  ]o'.letter.'  :<c-u>'.cmd2.'<cr>'
        exe 'nno  <silent><unique>  co'.letter.'  :<c-u>'.rhs3.'<cr>'

        return

    elseif a:0 ==# 3
        let [a_func, letter, values] = [a:1, a:2, eval(a:3)]
        exe 'nno  <silent><unique>  [o'.letter.'  :<c-u>call <sid>'.a_func.'(0)<cr>'
        exe 'nno  <silent><unique>  ]o'.letter.'  :<c-u>call <sid>'.a_func.'(1)<cr>'
        exe 'nno  <silent><unique>  co'.letter.'  :<c-u>call <sid>'.a_func.'(0,'.values[0].','.values[1].')<cr>'

        return

    elseif a:0 ==# 2
        let [label, letter, cmd1, cmd2, msg1, msg2, test] = [
            \ a:1,
            \ a:2,
            \ 'setl '.a:1,
            \ 'setl no'.a:1,
            \ '['.a:1.'] ON',
            \ '['.a:1.'] OFF',
            \ '&l:'.a:1,
            \ ]
    else
        return
    endif

    let rhs3 =  '     if '.test
    \          .'<bar>    exe '.string(cmd2).'<bar>echo '.string(msg2)
    \          .'<bar>else'
    \          .'<bar>    exe '.string(cmd1).'<bar>echo '.string(msg1)
    \          .'<bar>endif'

    exe 'nno  <silent><unique>  [o'.letter.'  :<c-u>'.cmd1.'<bar>echo '.string(msg1).'<cr>'
    exe 'nno  <silent><unique>  ]o'.letter.'  :<c-u>'.cmd2.'<bar>echo '.string(msg2).'<cr>'
    exe 'nno  <silent><unique>  co'.letter.'  :<c-u>'.rhs3.'<cr>'
endfu

fu! s:verbose_errors(enable) abort "{{{2
    let g:my_verbose_errors = a:enable ? 1 : 0
    echo '[verbose errors] '.(g:my_verbose_errors ? 'ON' : 'OFF')
endfu

fu! s:virtualedit(action) abort "{{{2
    if a:action is# 'is_all'
        return exists('s:ve_save')
    elseif a:action is# 'enable' && !exists('s:ve_save')
        let s:ve_save = &ve
        set ve=all
    elseif a:action is# 'disable' && exists('s:ve_save')
        let &ve = get(s:, 've_save', 'block')
        unlet! s:ve_save
    endif
    redraws!
endfu

" Mappings {{{1
" 2 "{{{2

call s:toggle_settings('cursorcolumn'  , 'o')
call s:toggle_settings('hlsearch'      , 'h')
call s:toggle_settings('list'          , 'I')
call s:toggle_settings('previewwindow' , 'P')
call s:toggle_settings('showcmd'       , 'W')
call s:toggle_settings('spell'         , 's')
call s:toggle_settings('wrap'          , 'w')

" 3 {{{2

call s:toggle_settings('conceallevel',
\                      'c',
\                      '[0, 3]')

call s:toggle_settings('stl_list_position',
\                      'i',
\                      '[0, 0]')
"                        ^  ^
"                        doesn't matter, we don't use these values
"                        TODO:
"                        if we don't use them, something should be improved
"                        in the design of `s:toggle_settings()`

" Do NOT use `]L`: it's already taken to move to the last entry in the ll.
call s:toggle_settings('lightness',
\                      'l',
\                      '[253, 256]' )

" 5 {{{2

call s:toggle_settings('colorscheme',
\                      'C',
\                      'call <sid>colorscheme(1)',
\                      'call <sid>colorscheme(0)',
\                      '&bg is# "light"')

" Mnemonic:
" D for Debug
call s:toggle_settings('verbose errors',
\                      'D',
\                      'call <sid>verbose_errors(1)',
\                      'call <sid>verbose_errors(0)',
\                      'get(g:, "my_verbose_errors", 0) ==# 1')

call s:toggle_settings('edit Help file',
\                      'H',
\                      'call <sid>edit_help_file(1)',
\                      'call <sid>edit_help_file(0)',
\                      'empty(maparg("q", "n", 0, 1))')

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
call s:toggle_settings('number',
\                      'n',
\                      'setl number relativenumber',
\                      'setl nonumber norelativenumber',
\                      '&l:nu')

call s:toggle_settings('MatchParen',
\                      'p',
\                      'call <sid>matchparen(1)',
\                      'call <sid>matchparen(0)',
\                      'exists("g:loaded_matchparen")')

" `gq` is  currently used  to format comments,  but it would  also be  useful to
" execute formatting tools such as js-beautify.
call s:toggle_settings('formatprg',
\                      'q',
\                      'call <sid>formatprg("global")',
\                      'call <sid>formatprg("local")',
\                      '&g:fp is# &l:fp')

" 7 {{{2

call s:toggle_settings('showbreak',
\                      'B',
\                      'setl showbreak=↪',
\                      'setl showbreak=',
\                      'ON',
\                      'OFF',
\                      '!empty(&sbr)')

call s:toggle_settings('diff',
\                      'd',
\                      'diffthis',
\                      'diffoff',
\                      'ON',
\                      'OFF',
\                      '&l:diff')

call s:toggle_settings('fugitive branch',
\                      'g',
\                      'let g:my_fugitive_branch = 1',
\                      'let g:my_fugitive_branch = 0',
\                      'ON',
\                      'OFF',
\                      'get(g:, "my_fugitive_branch", 0)')

call s:toggle_settings('cursorline',
\                      'L',
\                      'call <sid>cursorline(1)',
\                      'call <sid>cursorline(0)',
\                      'ON',
\                      'OFF',
\                      'exists("#my_cursorline")')

call s:toggle_settings('nrformats',
\                      'N',
\                      'setl nf+=alpha',
\                      'setl nf-=alpha',
\                      '+alpha',
\                      '-alpha',
\                      'index(split(&l:nf, ","), "alpha") >= 0')

call s:toggle_settings('spelllang',
\                      'S',
\                      'setl spl=fr',
\                      'setl spl=en',
\                      'FR',
\                      'EN',
\                      '&l:spl is# "fr"')

call s:toggle_settings('fold title',
\                      't',
\                      'let b:foldtitle_full=1 <bar> redraw!',
\                      'let b:foldtitle_full=0 <bar> redraw!',
\                      'full',
\                      'short',
\                      'get(b:, "foldtitle_full", 0)')

call s:toggle_settings('virtualedit',
\                      'v',
\                      'call <sid>virtualedit("enable")',
\                      'call <sid>virtualedit("disable")',
\                      'ALL',
\                      '∅',
\                      '<sid>virtualedit("is_all")')

call s:toggle_settings('hl yanked text',
\                      'y',
\                      'call <sid>toggle_hl_yanked_text("enable")',
\                      'call <sid>toggle_hl_yanked_text("disable")',
\                      'ON',
\                      'OFF',
\                      '<sid>toggle_hl_yanked_text("is_active")')

" Vim uses `z` as a prefix to build all fold-related commands in normal mode.
call s:toggle_settings('auto open folds',
\                      'z',
\                      'call <sid>auto_open_fold("enable")',
\                      'call <sid>auto_open_fold("disable")',
\                      'ON',
\                      'OFF',
\                      '<sid>auto_open_fold("is_active")')
"                        │
"                        └ We can't use a  script-local variable, because we can't
"                          access it from a mapping:
"
"                                   exists('s:my_var')       ✘
"                                   exists('<sid>my_var')    ✘

