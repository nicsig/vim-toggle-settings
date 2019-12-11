if exists('g:autoloaded_toggle_settings')
    finish
endif
let g:autoloaded_toggle_settings = 1

" FAQ {{{1

" I want to toggle between the global value and the local value of a buffer-local option.
" Which one should I consider to be the "enabled" state?{{{
"
" The local value.
" It makes sense,  because usually when you  enable sth, you tend  to think it's
" special (e.g.  you enter a  temporary special mode);  the global value  is not
" special, it's common.
"}}}

" Don't forget to properly handle repeated (dis)activations. {{{
"
" Necessary when you save/restore a state with a custom variable.
"
" When you write a function  to activate/disactivate/toggle some state, do *not*
" assume it will only be used for repeated toggling.
" It can  also be  used for (accidental)  repeated activations,  or (accidental)
" repeated disactivations.
"
" There is no issue if the function  doesn't save/restore a state using a custom
" variable (ex:  `s:colorscheme()`).  But if it  does (ex: `#auto_open_fold()`),
" but doesn't handle repeated (dis)activations, it can lead to errors.
"
" For example,  if you transit to  the same state  twice, the 1st time,  it will
" work as expected: the  function will save the original state,  A, then put you
" in the new state B.
" But the 2nd time, the function will blindly save B, as if it was A.
" So, when you will invoke it to restore A, you will, in effect, restore B.
"}}}
"   Ok, but concretely, what should I avoid?{{{
"
" *Never* write this:
"
"        ┌ boolean argument:
"        │
"        │      - when it's 1 it means we want to enable  some state
"        │      - "         0                     disable "
"        │
"     if a:enable                       ✘
"         let s:save = ...
"             │
"             └ save current state for future restoration
"         ...
"     else                              ✘
"         ...
"     endif
"
" Instead:
"
"     if a:enable && is_disabled        ✔
"         let s:save = ...
"         ...
"     elseif a:disable && is_enabled    ✔
"         ...
"     endif
"
" ---
"
" The tricky part is finding the right expression for `is_disabled` and `is_enabled`.
" If you want  to toggle an option with  only 2 possible values –  e.g. 'on' and
" 'off' – then it's easy:
"
"     is_disabled = opt is# 'off'
"     is_enabled  = opt is# 'on'
"
" If you want to  alternate between 2 values – e.g. 'a' and  'c' – for an option
" which can have  more than 2 values –  e.g. 'a', 'b' and 'c' –  then it's still
" easy, but there is a catch:
"
"     is_disabled = opt isnot# 'c'
"     is_enabled  = opt isnot# 'a'
"                       │
"                       └ you have to use a negative assertion,
"                         otherwise your code would not handle correctly the case
"                         where `opt` has the value `b` (set by accident or by another plugin)
"
" ---
"
" In any case, an ad-hoc variable is not a good proxy to write `is_enabled` and `is_disabled`:
"
"     if a:disable && is_enabled
"     →
"     if a:disable && exists('s:opt_save')
"                     ├──────────────────┘
"                     └ wrong: `opt` could have been enabled manually via a `:set` command (or by another plugin)
"                       in which case `s:opt_save` does not exist, and yet `opt` *is* enabled
"
" Exception:
"
" If you are toggling  an ad-hoc feature which can *only*  be manipulated by the
" function you are writing, then an ad-hoc  variable is probably ok and may even
" be the only reliable way to write the expressions.
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

let s:fp_save = {}
let s:hl_yanked_text = 0

" Autocmds {{{1

augroup hl_yanked_text
    au!
    au TextYankPost * if s:toggle_hl_yanked_text('is_active') | call s:hl_yanked_text() | endif
augroup END

" Functions {{{1
fu s:toggle_settings(...) abort "{{{2
    if index([2, 3, 4], a:0) == -1 | return | endif

    if a:0 == 2
        let [letter, cmd1, cmd2, test] = [
            \ a:2,
            \ 'setl '..a:1,
            \ 'setl no'..a:1,
            \ '&l:'..a:1,
            \ ]

        let rhs3 =  'if '..test
            \ ..'<bar>    exe '..string(cmd2)
            \ ..'<bar>else'
            \ ..'<bar>    exe '..string(cmd1)
            \ ..'<bar>endif'

        exe 'nno <silent><unique> [o'..letter..' :<c-u>'..cmd1..'<cr>'
        exe 'nno <silent><unique> ]o'..letter..' :<c-u>'..cmd2..'<cr>'
        exe 'nno <silent><unique> co'..letter..' :<c-u>'..rhs3..'<cr>'

    elseif a:0 == 3
        let [a_func, letter, values] = [a:1, a:2, eval(a:3)]
        exe 'nno <silent><unique> [o'..letter..' :<c-u>call <sid>'..a_func..'(0)<cr>'
        exe 'nno <silent><unique> ]o'..letter..' :<c-u>call <sid>'..a_func..'(1)<cr>'
        exe 'nno <silent><unique> co'..letter..' :<c-u>call <sid>'..a_func..'(0,'..values[0]..','..values[1]..')<cr>'

    elseif a:0 == 4
        let [letter, cmd1, cmd2, test] = a:000

        let rhs3 = '     if '..test
            \ ..'<bar>    exe '..string(cmd2)
            \ ..'<bar>else'
            \ ..'<bar>    exe '..string(cmd1)
            \ ..'<bar>endif'

        exe 'nno <silent><unique> [o'..letter..' :<c-u>'..cmd1..'<cr>'
        exe 'nno <silent><unique> ]o'..letter..' :<c-u>'..cmd2..'<cr>'
        exe 'nno <silent><unique> co'..letter..' :<c-u>'..rhs3..'<cr>'
    endif
endfu

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
    "     fu s:auto_open_fold(action) abort
    "         if a:action is# 'enable' && &foldopen isnot# 'all'
    "             let s:fold_options_save = {
    "                 \ 'open'   : &foldopen,
    "                 \ 'close'  : &foldclose,
    "                 \ 'enable' : &foldenable,
    "                 \ 'level'  : &foldlevel,
    "                 \ }
    "             " Consider setting 'foldnestmax' if you use 'indent'/'syntax' as a folding method.{{{
    "             "
    "             " If you set the local value of  'fdm' to 'indent' or 'syntax', Vim will
    "             " automatically fold the buffer according to its indentation / syntax.
    "             "
    "             " It can lead to deeply nested folds. This can be annoying when you have
    "             " to open  a lot of  folds to  read the contents  of a line.
    "             "
    "             " One way to tackle this issue  is to reduce the value of 'foldnestmax'.
    "             " By default  it's 20 (which is  the deepest level of  nested folds that
    "             " Vim can produce with these 2 methods  anyway). If you set it to 1, Vim
    "             " will only produce folds for the outermost blocks (functions/methods).
    "            "}}}
    "             set foldclose=all
    "             set foldopen=all
    "             set foldenable
    "             set foldlevel=0
    "         elseif a:action is# 'disable' && &foldopen is# 'all'
    "             for op in keys(s:fold_options_save)
    "                 exe 'let &fold'..op..' = s:fold_options_save.'..op
    "             endfor
    "             norm! zMzv
    "             unlet! s:fold_options_save
    "         endif
    "     endfu
    "     call s:toggle_settings(
    "         \ 'auto open fold',
    "         \ 'z',
    "         \ 'call <sid>auto_open_fold("enable")',
    "         \ 'call <sid>auto_open_fold("disable")',
    "         \ '&foldopen is# "all"',
    "         \ )
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
" It gives you a little more control about this feature.
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

fu s:colorscheme(type) abort "{{{2
    if a:type is# 'light'
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
        " For example, it's  useful to see a marker denoting  a concealed answer
        " to a question.
        " It could also be useful to pretty-print some logical/math symbols.
        "}}}
        if &ft is# 'markdown'
            let &l:cole = &l:cole == 2 ? 0 : 2
        else
            let &l:cole = &l:cole == a:1 ? a:2 : a:1
        endif
        echo '[conceallevel] '..&l:cole
        return
    endif

    if a:is_fwd
        let new_val = (&l:cole + 1)%(3+1)
    else
        let new_val = 3 - (3 - &l:cole + 1)%(3+1)
    endif

    " We are not interested in level 1. The 3 other levels are enough:{{{
    "
    "    ┌─────────────────────────────┬───┐
    "    │ everything                  │ 0 │
    "    ├─────────────────────────────┼───┤
    "    │ concealed but has a `cchar` │ 2 │
    "    ├─────────────────────────────┼───┤
    "    │ nothing                     │ 3 │
    "    └─────────────────────────────┴───┘
    "}}}
    if new_val == 1
        let new_val = a:is_fwd ? 2 : 0
    endif

    let &l:cole = new_val
    echo '[conceallevel] '..&l:cole
endfu

fu s:edit_help_file(allow) "{{{2
    if &ft isnot# 'help' | return | endif

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

        for pat in map(keys, {_,v -> '|\s*exe\s*''[nx]unmap\s*<buffer>\s*'..v.."'"})
            let b:undo_ftplugin = substitute(b:undo_ftplugin, pat, '', 'g')
        endfor

        setl ma noro bt=
        echo 'you CAN edit the file'

    elseif !a:allow && empty(maparg('q', 'n', 0, 1))
        " reload ftplugin
        edit
        setl noma ro bt=help
        echo 'you can NOT edit the file'
    endif
endfu

fu s:formatprg(scope) abort "{{{2
    if a:scope is# 'local' && &l:fp is# ''
        let bufnr = bufnr('%')
        if has_key(s:fp_save, bufnr)
            let &l:fp = s:fp_save[bufnr]
            unlet! s:fp_save[bufnr]
        endif
    elseif a:scope is# 'global' && &l:fp isnot# ''
        " save the local value on a per-buffer basis
        let s:fp_save[bufnr('%')] = &l:fp
        " clear the local value so that the global one is used
        set fp<
    endif
    echo '[formatprg] '..(!empty(&l:fp) ? &l:fp..' (local)' : &g:fp..' (global)')
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
    if a:enable
        setl sbr=↪
    elseif ! a:enable
        " Do *not* write `set sbr<`.{{{
        "
        " It would work as expected in Vim, but not in Nvim.
        " This is because, in the latter, `'sbr'` is still a global option.
        " In Vim, it  was made a global-local option in  8.1.2281, but the patch
        " has not been ported to Nvim yet.
        "
        " ---
        "
        " Here's what happens:
        "
        "    - in Vim, `:setl sbr=` empties the local value, which causes the
        "      global value to be used instead; and the global value is empty
        "
        "    - in Nvim, `:setl sbr=` empties the global value (because there is no local value)
        "
        " In both cases, (N)Vim uses the global value which is empty.
        " In effect, we've disabled the showbreak character.
        "}}}
        setl sbr=
    endif
endfu

fu s:toggle_hl_yanked_text(action) abort "{{{2
    if a:action is# 'is_active'
        return s:hl_yanked_text == 1
    elseif a:action is# 'enable'
        let s:hl_yanked_text = 1
    elseif a:action is# 'disable'
        let s:hl_yanked_text = 0
    endif
endfu

fu s:hl_yanked_text() abort
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

fu s:virtualedit(action) abort "{{{2
    if a:action is# 'enable'
        set ve=all
    elseif a:action is# 'disable'
        let &ve = ''
    endif
endfu
" }}}1

" Mappings {{{1
" 2 "{{{2

call s:toggle_settings('previewwindow', 'P')
call s:toggle_settings('hlsearch'     , 'h')
call s:toggle_settings('list'         , 'i')
call s:toggle_settings('spell'        , 's')
call s:toggle_settings('wrap'         , 'w')

" 3 {{{2

call s:toggle_settings(
    \ 'lightness',
    \ 'l',
    \ '[253, 256]',
    \ )

call s:toggle_settings(
    \ 'conceallevel',
    \ 'c',
    \ '[0, 3]',
    \ )

" 4 {{{2

call s:toggle_settings(
    \ '<space>',
    \ 'set diffopt+=iwhiteall',
    \ 'set diffopt-=iwhiteall',
    \ '&diffopt =~# "iwhiteall"',
    \ )

call s:toggle_settings(
    \ 'C',
    \ 'call <sid>colorscheme("dark")',
    \ 'call <sid>colorscheme("light")',
    \ '&bg is# "dark"',
    \ )

call s:toggle_settings(
    \ 'D',
    \ 'windo diffthis',
    \ 'diffoff! <bar> norm! zv',
    \ '&l:diff',
    \ )

" Do *not* use `]L`: it's already taken to move to the last entry in the ll.
call s:toggle_settings(
    \ 'L',
    \ 'call colorscheme#cursorline(1)',
    \ 'call colorscheme#cursorline(0)',
    \ '&l:cul',
    \ )

call s:toggle_settings(
    \ 'S',
    \ 'setl spl=fr<bar>echo "[spelllang] FR"',
    \ 'setl spl=en<bar>echo "[spelllang] EN"',
    \ '&l:spl is# "fr"',
    \ )

call s:toggle_settings(
    \ 'V',
    \ 'let g:my_verbose_errors = 1<bar>redrawt',
    \ 'let g:my_verbose_errors = 0<bar>redrawt',
    \ 'get(g:, "my_verbose_errors", 0) == 1',
    \ )

" How is it useful?{{{
"
" When we select a  column of `a`'s, it's useful to press `C-a`  and get all the
" alphabetical characters from `a` to `z`.
"
" ---
"
" We  use `a`  as the  suffix  for the  lhs,  because it's  easier to  remember:
" `*a*lpha`, `C-*a*`, ...
"}}}
call s:toggle_settings(
    \ 'a',
    \ 'setl nf+=alpha',
    \ 'setl nf-=alpha',
    \ 'index(split(&l:nf, ","), "alpha") >= 0',
    \ )

call s:toggle_settings(
    \ 'b',
    \ 'call <sid>showbreak(1)',
    \ 'call <sid>showbreak(0)',
    \ '&l:sbr isnot# ""',
    \ )

call s:toggle_settings(
    \ 'd',
    \ 'diffthis',
    \ 'diffoff <bar> norm! zv',
    \ '&l:diff',
    \ )

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
call s:toggle_settings(
    \ 'n',
    \ 'setl number relativenumber',
    \ 'setl nonumber norelativenumber',
    \ '&l:nu',
    \ )

call s:toggle_settings(
    \ 'p',
    \ 'call <sid>matchparen(1)',
    \ 'call <sid>matchparen(0)',
    \ 'g:matchup_matchparen_enabled',
    \ )

" `gq`  is currently  used to  format comments,  but it  can also  be useful  to
" execute formatting tools such as js-beautify in html/css/js files.
call s:toggle_settings(
    \ 'q',
    \ 'call <sid>formatprg("local")',
    \ 'call <sid>formatprg("global")',
    \ '&l:fp isnot# ""',
    \ )

call s:toggle_settings(
    \ 't',
    \ 'let b:foldtitle_full=1 <bar> redraw!',
    \ 'let b:foldtitle_full=0 <bar> redraw!',
    \ 'get(b:, "foldtitle_full", 0)',
    \ )

call s:toggle_settings(
    \ 'v',
    \ 'call <sid>virtualedit("enable")',
    \ 'call <sid>virtualedit("disable")',
    \ '&ve is# "all"',
    \ )

call s:toggle_settings(
    \ 'y',
    \ 'call <sid>toggle_hl_yanked_text("enable")',
    \ 'call <sid>toggle_hl_yanked_text("disable")',
    \ '<sid>toggle_hl_yanked_text("is_active")',
    \ )

" Vim uses `z` as a prefix to build all fold-related commands in normal mode.
call s:toggle_settings(
    \ 'z',
    \ 'call toggle_settings#auto_open_fold("enable")',
    \ 'call toggle_settings#auto_open_fold("disable")',
    \ 'exists("b:auto_open_fold_mappings")',
    \ )

call s:toggle_settings(
    \ '~',
    \ 'call <sid>edit_help_file(1)',
    \ 'call <sid>edit_help_file(0)',
    \ 'empty(maparg("q", "n", 0, 1))',
    \ )

" TODO: Is an  ad-hoc variable the only  reliable way to write  `is_enabled` and
" `is_disabled` when we're toggling an ad-hoc feature?
"
" Update: It doesn't  seem so. I've been able  to refactor the whole  script and
" never  inspect an  ad-hoc  variable inside  an  `is_enabled` or  `is_disabled`
" expression.
"
" So the  question is now,  when do  we need to  inspect an ad-hoc  variable (if
" ever) to write `is_enabled` or `is_disabled`?
"
" Answer: I think you  need to inspect an ad-hoc variable  iff the whole purpose
" of the mappings is to alter the value of this variable.
" IOW, the issue, here, is not using an ad-hoc variable, but using a proxy.
" You *can* use an ad-hoc variable, but *never* as a proxy for sth else (e.g. an
" option being set).
" Explain why  a proxy is bad  (hint: it has to  do with the fact  that it works
" only under the assumption that the feature you're toggling can only be toggled
" via your mapping, which is not always true; and even if it is true now, it may
" not be true in the future).
"
" Make sure we've never used a proxy for any toggling mapping.

" TODO: Study how relevant a FSM is to  toggle an option between 2 values, while
" it  can have  more than  2 (in  such a  case, a  FSM is  useful to  handle the
" unexpected  cases  where the  option  has  a value  other  than  the 2  you're
" accustomed to).

" TODO: Remove the `&& is_enabled`, `&& is_disabled` whenever it's useless (i.e.
" whenever we don't save any state in a persistent variable).

" TODO: Review our comments at the top of the file.

