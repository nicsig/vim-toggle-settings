if exists('g:autoloaded_toggle_settings')
    finish
endif
let g:autoloaded_toggle_settings = 1

" Don't forget to properly handle repeated (dis)activations. {{{
"
" Necessary when you save/restore a state with a custom variable.
"
" When you write a function  to activate/disactivate/toggle some state, do *not*
" assume it will only be used for repeated toggling.
" It  can also  be used  for (accidental)  repeated activation,  or (accidental)
" repeated disactivation.
"
" There is no issue if the function  doesn't save/restore a state using a custom
" variable (ex: `#cursorline()`).   But if it does  (ex: `s:virtualedit()`), but
" doesn't handle repeated (dis)activations, it can lead to errors.
"
" For example,  if you transit to  the same state  twice, the 1st time,  it will
" work as expected: the  function will save the original state,  A, then put you
" in the new state B.
" But the 2nd time, the function will blindly save B, as if it was A.
" So, when you will invoke it to restore A, you will, in effect, restore B.
"}}}
"   Ok, but concretely, what should I avoid?{{{
"
" NEVER write this:
"
"            ┌ boolean argument:
"            │
"            │      - when it's 1 it means we want to enable  some state
"            │      - "         0                     disable "
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
"   Which functions are concerned?{{{
"
" All functions make  you transit to a new known  state (are there exceptions?).
" But  some of  them do  it  from a  known state,  while  others do  it from  an
" *unknown* one.
" The  current issue  concerns  the latter,  because when  you  transit from  an
" unknown state, you have to save it first for the future restoration.
" You don't need to do that when you know it in advance.
"}}}

" Init {{{1

const s:AOF_LHS2NORM = {
    \ 'j': 'j',
    \ 'k': 'k',
    \ '<down>': "\<down>",
    \ '<up>': "\<up>",
    \ '<c-d>': "\<c-d>",
    \ '<c-u>': "\<c-u>",
    \ 'gg': 'gg',
    \ 'G': 'G',
    \ }

" Autocmds {{{1

augroup hl_yanked_text
    au!
    au TextYankPost * if s:toggle_hl_yanked_text('is_active') | call s:hl_yanked_text() | endif
augroup END

" Functions {{{1
fu toggle_settings#auto_open_fold(action) abort "{{{2
    if a:action is# 'enable' && !exists('b:auto_open_fold_mappings')
        if foldclosed('.') != -1
            norm! zvzz
        endif
        let b:auto_open_fold_mappings = lg#map#save('n', 1, keys(s:AOF_LHS2NORM))
        for lhs in keys(s:AOF_LHS2NORM)
            " Why do you open all folds with `zR`?{{{
            "
            " This is necessary when you scroll backward.
            "
            " Suppose you are  on the first line of  a fold and you move  one line back;
            " your cursor will *not* land on the previous line, but on the first line of
            " the previous fold.
            "}}}
            " Why `:sil!` before `:norm!`?{{{
            "
            " If you're on  the last line and  you try to move  forward, it will
            " fail, and the rest of the sequence (`zMzv`) will not be processed.
            " Same issue if you try to move backward while on the first line.
            " `silent!` makes sure that the whole sequence is processed no matter what.
            "}}}
            " Why `substitute(...)`?{{{
            "
            " To prevent some keys from being translated by `:nno`.
            " E.g., you don't want `<c-u>` to be translated into a literal `C-u`.
            " Because when you  press the mapping, `C-u` would not  be passed to
            " `s:move_and_open_fold()`;  instead, it  would  be  pressed on  the
            " command-line.
            "}}}
            exe printf(
            \ 'nno <buffer><nowait><silent> %s :<c-u>call <sid>move_and_open_fold(%s)<cr>',
            \     lhs,
            \     string(substitute(lhs, '^<\([^>]*>\)$', '<lt>\1', '')),
            \ )
        endfor
    elseif a:action is# 'disable' && exists('b:auto_open_fold_mappings')
        call lg#map#restore(b:auto_open_fold_mappings)
        unlet! b:auto_open_fold_mappings
    endif

    " Old Code:{{{
    "
    "     if a:action is# 'is_active'
    "         return exists('s:fold_options_save')
    "     elseif a:action is# 'enable' && !exists('s:fold_options_save')
    "         let s:fold_options_save = {
    "         \                           'close'  : &foldclose,
    "         \                           'open'   : &foldopen,
    "         \                           'enable' : &foldenable,
    "         \                           'level'  : &foldlevel,
    "         \                         }
    "
    "         " Consider setting 'foldnestmax' if you use 'indent'/'syntax' as a folding method.{{{
    "         "
    "         " If you set the local value of  'fdm' to 'indent' or 'syntax', Vim will
    "         " automatically fold the buffer according to its indentation / syntax.
    "         "
    "         " It can lead to deeply nested folds. This can be annoying when you have
    "         " to open  a lot of  folds to  read the contents  of a line.
    "         "
    "         " One way to tackle this issue  is to reduce the value of 'foldnestmax'.
    "         " By default  it's 20 (which is  the deepest level of  nested folds that
    "         " Vim can produce with these 2 methods  anyway). If you set it to 1, Vim
    "         " will only produce folds for the outermost blocks (functions/methods).
    "        "}}}
    "         set foldclose=all " close a fold if we leave it with any command
    "         set foldopen=all  " open  a fold if we enter it with any command
    "         set foldenable
    "         set foldlevel=0   " close all folds by default
    "     elseif a:action is# 'disable' && exists('s:fold_options_save')
    "         for op in keys(s:fold_options_save)
    "             exe 'let &fold'.op.' = s:fold_options_save.'.op
    "         endfor
    "         norm! zMzv
    "         unlet! s:fold_options_save
    "     endif
    "}}}
    "   What did it do?{{{
    "
    " It toggled  a *global* auto-open-fold  state, by (re)setting  some folding
    " options, such as `'foldopen'` and `'foldclose'`.
    "}}}
    "   Why don't you use it anymore?{{{
    "
    " In practice, that's never what I want.
    " I want to toggle a *local* state (local to the current buffer).
    "
    " ---
    "
    " Besides, suppose you want folds to be opened automatically in a given window.
    " You enable the feature.
    " After a while you're finished, and close the window.
    " Now you need to restore the state as it was before enabling it.
    " This is fiddly.
    "
    " OTOH, with a local state, you don't have anything to restore after closing
    " the window.
    "}}}
endfu

" Warning: Folds won't be opened/closed if the next line is in a new fold which is not closed.{{{
"
" This is because  we run `norm! zMzv`  iff the foldlevel has changed,  or if we
" get on a line in a closed fold.
"}}}
" Why don't you fix this?{{{
"
" Not sure how to fix this.
" Besides, I kinda like the current behavior.
" If you press `zR`, you can move with `j`/`k` in the buffer without folds being closed.
" If you press `zM`, folds are opened/closed automatically again.
" This gives you a little more control about this feature.
"}}}
fu s:move_and_open_fold(lhs) abort
    let old_foldlevel = foldlevel('.')
    let old_winline = winline()
    if a:lhs is# 'j' || a:lhs is# '<down>'
        norm! gj
        if &ft is# 'markdown' && getline('.') =~# '^#\+$' | return | endif
        let is_in_a_closed_fold = foldclosed('.') != -1
        let new_foldlevel = foldlevel('.')
        let level_changed = new_foldlevel != old_foldlevel
        " need to  check `level_changed` to handle  the case where we  move from
        " the end of a nested fold to the next line in the containing fold
        if (is_in_a_closed_fold || level_changed) && s:does_not_distract_in_goyo()
            norm! zMzv
            " Rationale:{{{
            "
            " I don't  mind the distance between  the cursor and the  top of the
            " window changing unexpectedly after pressing `j` or `k`.
            " In fact, the  way it changes now  lets us see a good  portion of a
            " fold when we enter it, which I like.
            "
            " However, in goyo mode, it's distracting.
            "}}}
            if get(g:, 'in_goyo_mode', 0) | call s:fix_winline(old_winline, 'j') | endif
        endif
    elseif a:lhs is# 'k' || a:lhs is# '<up>'
        norm! gk
        if &ft is# 'markdown' && getline('.') =~# '^#\+$' | return | endif
        let is_in_a_closed_fold = foldclosed('.') != -1
        let new_foldlevel = foldlevel('.')
        let level_changed = new_foldlevel != old_foldlevel
        " need to  check `level_changed` to handle  the case where we  move from
        " the start of a nested fold to the previous line in the containing fold
        if (is_in_a_closed_fold || level_changed) && s:does_not_distract_in_goyo()
            sil! norm! gjzRkzMzv
            "  │           │{{{
            "  │           └ don't use `gk` (github issue 4969; fixed but not merged in Nvim)
            "  └ make sure all the keys are pressed, even if an error occurs
            "}}}
            if get(g:, 'in_goyo_mode', 0) | call s:fix_winline(old_winline, 'k') | endif
        endif
    else
        " We want to pass a count if we've pressed `123G`.
        " But we don't want any count if we've just pressed `G`.
        let cnt = v:count ? v:count : ''
        sil! exe 'norm! zR'..cnt..s:AOF_LHS2NORM[a:lhs]..'zMzv'
    endif
endfu

fu s:does_not_distract_in_goyo() abort
    " In goyo mode, opening a fold containing only a long comment is distracting.
    " Because we only care about the code.
    if ! get(g:, 'in_goyo_mode', 0) || &ft is# 'markdown'
        return 1
    endif
    let cml = matchstr(get(split(&l:cms, '%s', 1), 0, ''), '\S*')
    " note that we allow opening numbered folds (because usually those can contain code)
    let fmr = '\%('..join(split(&l:fmr, ','), '\|')..'\)'
    return getline('.') !~# '^\s*\V'..escape(cml, '\')..'\m.*'..fmr..'$'
endfu

fu s:fix_winline(old, dir) abort
    let now = winline()
    if a:dir is# 'k'
        " getting one line closer from the top of the window is expected; nothing to fix
        if now == a:old - 1 | return | endif
        " if we were not at the top of the window before pressing `k`
        if a:old > (&so + 1)
            norm! zt
            let new = (a:old - 1) - (&so + 1)
            if new != 0 | exe 'norm! '..new.."\<c-y>" | endif
        " a:old == (&so + 1)
        else
            norm! zt
        endif
    elseif a:dir is# 'j'
        " getting one line closer from the bottom of the window is expected; nothing to fix
        if now == a:old + 1 | return | endif
        " if we were not at the bottom of the window before pressing `j`
        if a:old < (winheight(0) - &so)
            norm! zt
            let new = (a:old + 1) - (&so + 1)
            if new != 0 | exe 'norm! '..new.."\<c-y>" | endif
        " a:old == (winheight(0) - &so)
        else
            norm! zb
        endif
    endif
endfu

fu s:colorscheme(is_light) abort "{{{2
    if a:is_light
        colo seoul256-light
    else
        colo seoul256
    endif
endfu

fu s:conceallevel(is_fwd, ...) abort "{{{2
    if a:0
        " Why toggling between `0` and `2`, instead of `0` and `3` like everywhere else?{{{
        "
        " In a markdown file, we want to see `cchar`.
        " It's useful to see a marker denoting a concealed answer to a question,
        " for example. It could also be useful to pretty-print some logical/math
        " symbols.
        "}}}
        if &ft is# 'markdown'
            let &l:cole = &l:cole == 2 ? 0 : 2
        else
            let &l:cole = &l:cole == a:1 ? a:2 : a:1
        endif
        echo '[conceallevel] '..&l:cole
        return
    endif

    let new_val = a:is_fwd
              \ ?     (&l:cole + 1)%(3+1)
              \ :     3 - (3 - &l:cole + 1)%(3+1)

    " We are not interested in level 1.
    " The 3 other levels are enough. If I want to see:
    "
    "    - everything = 0
    "
    "    - what is useful = 2
    "      has a replacement character: `cchar`, {'conceal': 'x'}
    "
    "    - nothing = 3
    if new_val == 1
        let new_val = a:is_fwd ? 2 : 0
    endif

    let &l:cole = new_val
    echo '[conceallevel] '..&l:cole
endfu

fu s:edit_help_file(allow) "{{{2
    if &ft isnot# 'help'
        return
    endif
    if a:allow && !empty(maparg('q', 'n', 0, 1))
        nno <buffer><nowait><silent> <cr> 80<bar>

        let keys =<< trim END
            p
            q
            u
        END
        for a_key in keys
            exe 'sil unmap <buffer> '..a_key
        endfor

        for pat in map(keys, {_,v ->  '|\s*exe\s*''[nx]unmap\s*<buffer>\s*'..v.."'"})
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

fu s:formatprg(scope) abort "{{{2
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
        "     $ sudo npm -g install js-beautify
        "
        " Documentation:
        " https://github.com/beautify-web/js-beautify
        "
        " The tool has  many options, you can use the  ones you find interesting
        " in the value of 'fp'.
        let &l:fp = get(s:local_fp_save, bufnr('%'), &l:fp)
        unlet! s:local_fp_save[bufnr('%')]
    endif
    echo '[formatprg] '..(!empty(&l:fp) ? &l:fp : &g:fp)
endfu

fu s:hl_yanked_text() abort "{{{2
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
            let pat = '\%'..line('.')..'l\%'..virtcol('.')..'v\_.\{'..strchars(text, 1)..'}'
        elseif type is# 'V'
            let pat = '\%'..line('.')..'l\_.*\%'..(line('.')+len(text)-1)..'l'
        elseif type =~# "\<c-v>"..'\d\+'
            let width = matchstr(type, "\<c-v>"..'\zs\d\+')
            let [line, vcol] = [line('.'), virtcol('.')]
            let pat = join(map(text, {i -> '\%'..(line+i)..'l\%'..vcol..'v.\{'..width..'}'}), '\|')
        endif

        let id = matchadd('IncSearch', pat, 0, -1)
        call timer_start(250, {_ -> exists('id') ? matchdelete(id) : ''})
    catch
        return lg#catch_error()
    endtry
endfu

fu s:lightness(more, ...) abort "{{{2
    " toggle between 2 predefined levels of lightness
    if a:0
        if &bg is# 'light'
            let g:seoul256_light_background =
                \ get(g:, 'seoul256_light_background', g:seoul256_default_lightness) == a:1 ? a:2 : a:1
            colo seoul256-light
            let level = get(g:, 'seoul256_light_background', g:seoul256_default_lightness) - 252 + 1
        else
            let g:seoul256_background =
                \ get(g:, 'seoul256_background', 237) == 233 ? 237 : 233
            colo seoul256
            let level = get(g:, 'seoul256_background', 237) - 233 + 1
        endif

        call timer_start(0, {_ -> execute('echo "[lightness]"'..level, '')})
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
        "    - initialize `n` to 0
        "    - use the formula  (n+1)%(p+1)  to update `n`
        "                        ├─┘ ├────┘
        "                        │   └ but don't go above `p`
        "                        │     read this as:  “p+1 is off-limit”
        "                        │
        "                        └ increment
        "
        " To use this solution, we need to find a link between the problem we've
        " just solved and our original problem.
        " In the latter, what cycles between 0 and `p`?: the distance between `a` and `n`.
        "
        " Updated Solution:
        "                      before, it was `0`
        "                      v
        "    - initialize `n` to `a`
        "
        "    - use `(d+1)%(p+1)` to update the DISTANCE between `a` and `n`
        "           │                                         │
        "           │                                         └ before, it was `0`
        "           └ before, it was `n`
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
        "                   │       │      └ we want the distance from 0, not from `a`; so add `a`
        "                   │       └ but don't go too far
        "                   └ move away (+1) from `a` (n1-a)
    "}}}
        " How to make a number cycle through [a+p, a+p-1, ..., a] ?{{{
        "
        " We want to cycle from `a+p` down to `a`.
        "
        "    - initialize `n` to `a+p`
        "    - use the formula  (d+1)%(p+1)  to update the DISTANCE between `n` and `a+p`
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
        let g:seoul256_light_background = get(g:, 'seoul256_light_background', g:seoul256_default_lightness)

        " update `g:seoul256_light_background`
        let g:seoul256_light_background = a:more
            \ ? (g:seoul256_light_background - 252 + 1)%(4+1) + 252
            \ : 256 - (256 - g:seoul256_light_background +1)%(4+1)

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
            \ ? (g:seoul256_background - 233 + 1)%(6+1) + 233
            \ : 239 - (239 - g:seoul256_background +1)%(6+1)

        colo seoul256
        let level = g:seoul256_background - 233 + 1
    endif

    call timer_start(0, {_ -> execute('echo "[lightness]"'..level, '')})
    return ''
endfu

fu s:matchparen(enable) abort "{{{2
    if empty(globpath(&rtp, 'macros/matchparen_toggle.vim', 0, 1, 1))
        echo printf('no  %s  file was found in the runtimepath', 'macros/matchparen.vim')
        return
    endif
    if a:enable && ! g:matchup_matchparen_enabled
       \ || ! a:enable && g:matchup_matchparen_enabled
        runtime! macros/matchparen_toggle.vim
    endif
    echo '[matchparen] '..(g:matchup_matchparen_enabled ? 'ON' : 'OFF')
endfu

fu s:showbreak(enable) abort "{{{2
    let &showbreak = a:enable ? '↪' : ''
    " Used in the autocmd `my_showbreak` in vimrc to (re)set `'showbreak'`.
    let b:showbreak = a:enable
endfu

fu s:toggle_hl_yanked_text(action) abort "{{{2
    if a:action is# 'is_active'
        return exists('s:hl_yanked_text')
    elseif a:action is# 'enable' && !exists('s:hl_yanked_text')
        let s:hl_yanked_text = 1
    elseif a:action is# 'disable' && exists('s:hl_yanked_text')
        unlet! s:hl_yanked_text
    endif
endfu

fu s:toggle_settings(...) abort "{{{2
    if a:0 == 7
        let [label, letter, cmd1, cmd2, msg1, msg2, test] = a:000
        let msg1 = '['..label..'] '..msg1
        let msg2 = '['..label..'] '..msg2

    elseif a:0 == 5
        let [label, letter, cmd1, cmd2, test] = a:000

        let rhs3 = '     if '..test
            \ ..'<bar>    exe '..string(cmd2)
            \ ..'<bar>else'
            \ ..'<bar>    exe '..string(cmd1)
            \ ..'<bar>endif'

        exe 'nno  <silent><unique>  [o'..letter..'  :<c-u>'..cmd1..'<cr>'
        exe 'nno  <silent><unique>  ]o'..letter..'  :<c-u>'..cmd2..'<cr>'
        exe 'nno  <silent><unique>  co'..letter..'  :<c-u>'..rhs3..'<cr>'

        return

    elseif a:0 == 3 && a:3 isnot# 'silent'
        let [a_func, letter, values] = [a:1, a:2, eval(a:3)]
        exe 'nno  <silent><unique>  [o'..letter..'  :<c-u>call <sid>'..a_func..'(0)<cr>'
        exe 'nno  <silent><unique>  ]o'..letter..'  :<c-u>call <sid>'..a_func..'(1)<cr>'
        exe 'nno  <silent><unique>  co'..letter..'  :<c-u>call <sid>'..a_func..'(0,'..values[0]..','..values[1]..')<cr>'

        return

    elseif a:0 == 2 || a:0 == 3 && a:3 is# 'silent'
        let [label, letter, cmd1, cmd2, msg1, msg2, test] = [
            \ a:1,
            \ a:2,
            \ 'setl '..a:1,
            \ 'setl no'..a:1,
            \ get(a:, '3', '') is# 'silent' ? '' : '['..a:1..'] ON',
            \ get(a:, '3', '') is# 'silent' ? '' : '['..a:1..'] OFF',
            \ '&l:'..a:1,
            \ ]
    else
        return
    endif

    let rhs3 =  'if '..test
        \ ..'<bar>    exe '..string(cmd2)..'<bar>echo '..string(msg2)
        \ ..'<bar>else'
        \ ..'<bar>    exe '..string(cmd1)..'<bar>echo '..string(msg1)
        \ ..'<bar>endif'

    exe 'nno <silent><unique> [o'..letter..' :<c-u>'..cmd1..'<bar>echo '..string(msg1)..'<cr>'
    exe 'nno <silent><unique> ]o'..letter..' :<c-u>'..cmd2..'<bar>echo '..string(msg2)..'<cr>'
    exe 'nno <silent><unique> co'..letter..' :<c-u>'..rhs3..'<cr>'
endfu

fu s:verbose_errors(enable) abort "{{{2
    let g:my_verbose_errors = a:enable ? 1 : 0
    echo '[verbose errors] '..(g:my_verbose_errors ? 'ON' : 'OFF')
endfu

fu s:virtualedit(action) abort "{{{2
    if a:action is# 'is_all'
        return exists('s:ve_save')
    elseif a:action is# 'enable' && !exists('s:ve_save')
        let s:ve_save = &ve
        set ve=all
    elseif a:action is# 'disable' && exists('s:ve_save')
        let &ve = get(s:, 've_save', 'block')
        unlet! s:ve_save
    endif
    redrawt
endfu
" }}}1

" Mappings {{{1
" 2 "{{{2

call s:toggle_settings('previewwindow' , 'P', 'silent')
call s:toggle_settings('showcmd'       , 'W')
call s:toggle_settings('hlsearch'      , 'h')
call s:toggle_settings('list'          , 'i', 'silent')
call s:toggle_settings('cursorcolumn'  , 'o', 'silent')
call s:toggle_settings('spell'         , 's')
call s:toggle_settings('wrap'          , 'w')

" 3 {{{2

call s:toggle_settings('lightness',
\                      'l',
\                      '[253, 256]' )

call s:toggle_settings('conceallevel',
\                      'c',
\                      '[0, 3]')

" 5 {{{2

call s:toggle_settings('iwhiteall',
\                      '<space>',
\                      'set diffopt+=iwhiteall',
\                      'set diffopt-=iwhiteall',
\                      '&diffopt =~# "iwhiteall"')

call s:toggle_settings('colorscheme',
\                      'C',
\                      'call <sid>colorscheme(1)',
\                      'call <sid>colorscheme(0)',
\                      '&bg is# "light"')

call s:toggle_settings('diff everything',
\                      'D',
\                      'windo diffthis',
\                      'diffoff! <bar> norm! zv',
\                      '&l:diff')

" Mnemonic:
call s:toggle_settings('verbose errors',
\                      'V',
\                      'call <sid>verbose_errors(1)',
\                      'call <sid>verbose_errors(0)',
\                      'get(g:, "my_verbose_errors", 0) == 1')

call s:toggle_settings('diff',
\                      'd',
\                      'diffthis',
\                      'diffoff <bar> norm! zv',
\                      '&l:diff')

" Do *not* use `]L`: it's already taken to move to the last entry in the ll.
call s:toggle_settings('cursorline',
\                      'L',
\                      'call colorscheme#cursorline(1)',
\                      'call colorscheme#cursorline(0)',
\                      'exists("#my_cursorline")')

" Alternative:{{{
" The following mapping/function allows to cycle through 3 states:
"
"    1. nonumber + norelativenumber
"    2. number   +   relativenumber
"    3. number   + norelativenumber
"
" ---
"
"     nno <silent> con :<c-u>call <sid>numbers()<cr>
"
"     fu s:numbers() abort
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
\                      'exists("#matchup_matchparen#CursorMoved")')

" `gq` is  currently used  to format comments,  but it would  also be  useful to
" execute formatting tools such as js-beautify.
call s:toggle_settings('formatprg',
\                      'q',
\                      'call <sid>formatprg("global")',
\                      'call <sid>formatprg("local")',
\                      '&g:fp is# &l:fp')

call s:toggle_settings('virtualedit',
\                      'v',
\                      'call <sid>virtualedit("enable")',
\                      'call <sid>virtualedit("disable")',
\                      '<sid>virtualedit("is_all")')

" Vim uses `z` as a prefix to build all fold-related commands in normal mode.
call s:toggle_settings('auto open fold',
\                      'z',
\                      'call toggle_settings#auto_open_fold("enable")',
\                      'call toggle_settings#auto_open_fold("disable")',
\                      'exists("b:auto_open_fold_mappings")')

call s:toggle_settings('edit help file',
\                      '~',
\                      'call <sid>edit_help_file(1)',
\                      'call <sid>edit_help_file(0)',
\                      'empty(maparg("q", "n", 0, 1))')

" 7 {{{2

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

call s:toggle_settings('showbreak',
\                      'b',
\                      'call <sid>showbreak(1)',
\                      'call <sid>showbreak(0)',
\                      'ON',
\                      'OFF',
\                      '!empty(&sbr)')

call s:toggle_settings('fugitive branch',
\                      'g',
\                      'let g:my_fugitive_branch = 1',
\                      'let g:my_fugitive_branch = 0',
\                      'ON',
\                      'OFF',
\                      'get(g:, "my_fugitive_branch", 0)')

call s:toggle_settings('fold title',
\                      't',
\                      'let b:foldtitle_full=1 <bar> redraw!',
\                      'let b:foldtitle_full=0 <bar> redraw!',
\                      'full',
\                      'short',
\                      'get(b:, "foldtitle_full", 0)')

call s:toggle_settings('hl yanked text',
\                      'y',
\                      'call <sid>toggle_hl_yanked_text("enable")',
\                      'call <sid>toggle_hl_yanked_text("disable")',
\                      'ON',
\                      'OFF',
\                      '<sid>toggle_hl_yanked_text("is_active")')
"                        │
"                        └ We can't use a  script-local variable, because we can't
"                          access it from a mapping:
"
"                              exists('s:my_var')       ✘
"                              exists('<sid>my_var')    ✘

