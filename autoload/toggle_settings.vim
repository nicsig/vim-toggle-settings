if exists('g:autoloaded_toggle_settings')
    finish
endif
let g:autoloaded_toggle_settings = 1

" FAQ {{{1

" Don't forget to properly handle repeated (dis)activations. {{{
"
" It's necessary when your (dis)activation  has a side effect like (re)setting a
" persistent variable.
"
" ---
"
" When you write a function  to activate/disactivate/toggle some state, do *not*
" assume it will only be used for repeated toggling.
" It can  also be  used for (accidental)  repeated activations,  or (accidental)
" repeated disactivations.
"
" There is no issue if the  function has no side effect (ex: `s:colorscheme()`).
" But if it does (e.g. `#auto_open_fold()` creates a `b:` variable), and doesn't
" handle repeated (dis)activations, you can experience an unexpected behavior.
"
" For example, let's assume the function saves in a variable some info necessary
" to restore the current state.
" If  you transit  to  the same  state  twice, the  1st time,  it  will work  as
" expected: the function will save the info about the current state, A, then put
" you in the new state B.
" But the  2nd time,  the function will  again save the  info about  the current
" state – now B – overwriting the info about A.
" So, when you will invoke it to restore A, you will, in effect, restore B.
"}}}
"   Ok, but concretely, what should I avoid?{{{
"
" *Never* write this:
"
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
"     elseif !a:enable && is_enabled   ✔
"         ...
"     endif
"
" Note that  in this pseudo-code, you  don't really need `&&  is_enabled` in the
" `elseif` block, because it doesn't show any code with a side effect.
" Still, the  code is slightly more  readable when the 2  guards are constructed
" similarly.
" Besides, it  makes the  code more  future-proof; if  one of  the `if`/`elseif`
" blocks has a side effect now, there is  a good chance that, one day, the other
" one will *also* have a side effect.
"
" ---
"
" You have to write the right expressions for `is_disabled` and `is_enabled`.
" If you want  to toggle an option with  only 2 possible values –  e.g. 'on' and
" 'off' – then it's easy:
"
"     is_enabled = opt is# 'on'
"     is_disabled = opt is# 'off'
"
" But  if you  want to  toggle an  option with  more than  2 values  – e.g.  'a'
" (enabled), 'b' and 'c' (disabled) – then there is a catch.
" The assertions *must* be negative to handle  the case where the option has the
" unexpected value 'b'.
"
" For example, you should not write this:
"
"     is_enabled = opt is# 'a'
"     is_disabled = opt is# 'c'
"
" But this:
"
"                      v----v
"     is_enabled = opt isnot# 'a'
"     is_disabled = opt isnot# 'c'
"                       ^----^
"
" With the  first code, if `opt`  has the the value  'b' (set by accident  or by
" another plugin), your `if`/`elseif` blocks would never be run.
" With the  second code, if `opt`  has the value  'b', it will always  be either
" enabled (set to 'a') or disabled (set to 'c').
"}}}

" What is a proxy expression?{{{
"
" An expression that you inspect to determine  whether a state X is enabled, but
" which is never referred to in the definition of the latter.
"
" Example:
"
" When we press `[oq`, the state "local value of 'fp' is used" is enabled; let's
" call this state X.
"
" When we disable X, `s:fp_save` is created inside `s:formatprg()`.
" So, to  determine whether X  is enabled,  you could check  whether `s:fp_save`
" exists; if it does not, then X is enabled.
" But when you define  what X is, you don't need to refer  to `s:fp_save` at any
" point;  so if  you're  inspecting  `s:fp_save`, you're  using  it  as a  proxy
" expression; it's a proxy for the state X.
"}}}
"   Why is it bad to use one?{{{
"
" It works only under the assumption that  the state you're toggling can only be
" toggled via your mapping  (e.g. `coq`), which is not always  true; and even if
" it is true now, it may not be true in the future.
"
" For  example, the  non-existence of  `s:fp_save` does  not guarantee  that the
" local value of `'fp'` is used.
" The local value could have been emptied  by a third-party plugin (or you could
" have done it  manually with a `:set[l]` command); in  which case, you're using
" the global value, and yet `s:fp_save` does not exist.
"}}}
"     When is it still ok to use one?{{{
"
" When the expression is *meant* to be used as a proxy, and is not ad-hoc.
"
" For example, we use a proxy expression for matchparen; we inspect the value of
" `g:matchup_matchparen_enabled`.  It's  meant to  be used as  a proxy  to check
" whether the matchparen module of matchup is enabled.
"
" The alternative would be  to read the source code of  `vim-matchup` to get the
" name of  the autocmd which  implements the automatic highlighting  of matching
" words.
" But that  would be unreliable, because  it's part of the  implementation which
" may change at any time (e.g. after a refactoring).
" OTOH, the `g:` variable is reliable, because it's part of the interface of the
" plugin; as such, the plugin author should not change its name or remove it, at
" least if they care about backward compatibility.
"}}}

" I want to toggle between the global value and the local value of a buffer-local option.{{{
"}}}
"   Which one should I consider to be the "enabled" state?{{{
"
" The local value.
" It makes sense,  because usually when you  enable sth, you tend  to think it's
" special (e.g.  you enter a  temporary special mode);  the global value  is not
" special, it's common.
"}}}

" About the scrollbind feature: what's the relative offset?{{{
"
" It's the difference between the topline  of the current window and the topline
" of the other bound window.
"
" From `:h 'sbo`:
"
"    > jump      Applies to the offset between two windows for vertical
"    >           scrolling.  This offset is the difference in the first
"    >           displayed line of the bound windows.
"
" And from `:h scrollbind-relative`:
"
"    > Each 'scrollbind' window keeps track of its "relative offset," which can be
"    > thought of as the difference between the current window's vertical scroll
"    > position and the other window's vertical scroll position.
"}}}
" What's the effect of the `jump` flag in `'sbo'`?{{{
"
" It's included by default; if you remove it, here's what happens:
"
"     $ vim -Nu NONE -S <(cat <<'EOF'
"         set scb sbo=ver lines=24 nu
"         e /tmp/file1
"         sil pu =range(char2nr('a'), char2nr('z'))->map({_, v -> nr2char(v)})->repeat(2)
"         bo vs /tmp/file2
"         sil pu =range(char2nr('a'), char2nr('z'))->map({_, v -> nr2char(v)})
"         windo 1
"         1wincmd w
"     EOF
"     )
"
" Now, press:
"
"    - `jk`
"
"       Necessary to avoid what seems to be a bug,
"       where the second window doesn't scroll when you immediately press `G`.
"
"    - `G` to jump at the end of the buffer
"
"    - `C-w w` twice to focus the second window and come back
"
"       You don't need to press it twice to expose the behavior we're going to discuss;
"       once is enough;
"       twice just makes the effect more obvious.
"
" The relative offset is not 0 anymore, but 5.
" This is confirmed by the fact that  if you press `k` repeatedly to scroll back
" in the  first window, the  difference between the toplines  constantly remains
" equal to 5.
"
" When you reach the top of the buffer, the offset decreases down to 0.
" But when you press `j` to scroll down, the offset quickly gets back to 5.
"
" I don't know  how this behavior can  be useful; I find it  confusing, so don't
" remove `jump` from `'sbo'`.
"
" Note that this effect is cancelled if you also set `'crb'`.
"
" For more info, see:
"
"     :h 'scb
"     :h 'sbo
"     :h scroll-binding
"     :h scrollbind-relative
"}}}

" Init {{{1

import Catch from 'lg.vim'
import {MapSave, MapRestore} from 'lg/map.vim'

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

const s:SMC_BIG = 3000

const s:HL_TIME = 250

let s:fp_save = {}
let s:hl_yanked_text = 0
let s:scb_save = {}
let s:smc_save = {}

" Autocmds {{{1

augroup hl_yanked_text | au!
    au TextYankPost * if s:hl_yanked_text('is_active') | call s:auto_hl_yanked_text() | endif
augroup END

" Functions {{{1
fu s:toggle_settings(...) abort "{{{2
    if index([2, 4], a:0) == -1 | return | endif

    if a:0 == 2
        let [letter, cmd1, cmd2, test] = [
            \ a:1,
            \ 'setl ' .. a:2,
            \ 'setl no' .. a:2,
            \ '&l:' .. a:2,
            \ ]

        let rhs3 = 'if ' .. test
            \ .. '<bar>    exe ' .. string(cmd2)
            \ .. '<bar>else'
            \ .. '<bar>    exe ' .. string(cmd1)
            \ .. '<bar>endif'

        exe 'nno <silent><unique> [o' .. letter .. ' :<c-u>' .. cmd1 .. '<cr>'
        exe 'nno <silent><unique> ]o' .. letter .. ' :<c-u>' .. cmd2 .. '<cr>'
        exe 'nno <silent><unique> co' .. letter .. ' :<c-u>' .. rhs3 .. '<cr>'

    elseif a:0 == 4
        let [letter, cmd1, cmd2, test] = a:000

        let rhs3 = '     if ' .. test
            \ .. '<bar>    exe ' .. string(cmd2)
            \ .. '<bar>else'
            \ .. '<bar>    exe ' .. string(cmd1)
            \ .. '<bar>endif'

        exe 'nno <silent><unique> [o' .. letter .. ' :<c-u>' .. cmd1 .. '<cr>'
        exe 'nno <silent><unique> ]o' .. letter .. ' :<c-u>' .. cmd2 .. '<cr>'
        exe 'nno <silent><unique> co' .. letter .. ' :<c-u>' .. rhs3 .. '<cr>'
    endif
endfu

fu toggle_settings#auto_open_fold(enable) abort "{{{2
    if a:enable && !exists('b:auto_open_fold_mappings')
        if foldclosed('.') != -1
            norm! zvzz
        endif
        let b:auto_open_fold_mappings = keys(s:AOF_LHS2NORM)->s:MapSave('n', v:true)
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
                \ 'nno <buffer><nowait><silent> %s :<c-u>call <sid>move_and_open_fold(%s, %d)<cr>',
                \     lhs,
                \     substitute(lhs, '^<\([^>]*>\)$', '<lt>\1', '')->string(),
                \     v:count,
                \ )
        endfor
    elseif !a:enable && exists('b:auto_open_fold_mappings')
        call s:MapRestore(b:auto_open_fold_mappings)
        unlet! b:auto_open_fold_mappings
    endif

    " Old Code:{{{
    "
    "     fu s:auto_open_fold(enable) abort
    "         if a:enable && &foldopen isnot# 'all'
    "             let s:fold_options_save = {
    "                 \ 'open': &foldopen,
    "                 \ 'close': &foldclose,
    "                 \ 'enable': &foldenable,
    "                 \ 'level': &foldlevel,
    "                 \ }
    "             " Consider setting 'foldnestmax' if you use 'indent'/'syntax' as a folding method.{{{
    "             "
    "             " If you set the local value of  'fdm' to 'indent' or 'syntax', Vim will
    "             " automatically fold the buffer according to its indentation / syntax.
    "             "
    "             " It can lead to deeply nested folds.  This can be annoying when you have
    "             " to open  a lot of  folds to  read the contents  of a line.
    "             "
    "             " One way to tackle this issue  is to reduce the value of 'foldnestmax'.
    "             " By default  it's 20 (which is  the deepest level of  nested folds that
    "             " Vim can produce with these 2 methods  anyway).  If you set it to 1, Vim
    "             " will only produce folds for the outermost blocks (functions/methods).
    "            "}}}
    "             set foldclose=all
    "             set foldopen=all
    "             set foldenable
    "             set foldlevel=0
    "         elseif !a:enable && &foldopen is# 'all'
    "             for op in keys(s:fold_options_save)
    "                 exe 'let &fold' .. op .. ' = s:fold_options_save.' .. op
    "             endfor
    "             norm! zMzv
    "             unlet! s:fold_options_save
    "         endif
    "     endfu
    "     call s:toggle_settings(
    "         \ 'auto open fold',
    "         \ 'z',
    "         \ 'call <sid>auto_open_fold(1)',
    "         \ 'call <sid>auto_open_fold(0)',
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

" Warning: Do *not* change the name of this function.{{{
"
" If  you really  want  to, then  you'll  need to  refactor  other scripts;  run
" `:vimgrep` over all our Vimscript files to find out where we refer to the name
" of this function.
"}}}
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
fu s:move_and_open_fold(lhs, cnt) abort
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
            " `sil!` to make sure all the keys are pressed, even if an error occurs
            sil! norm! gjzRgkzMzv
            if get(g:, 'in_goyo_mode', 0) | call s:fix_winline(old_winline, 'k') | endif
        endif
    else
        " We want to pass a count if we've pressed `123G`.
        " But we don't want any count if we've just pressed `G`.
        let cnt = a:cnt ? a:cnt : ''
        sil! exe 'norm! zR' .. cnt .. s:AOF_LHS2NORM[a:lhs] .. 'zMzv'
    endif
endfu

fu s:does_not_distract_in_goyo() abort
    " In goyo mode, opening a fold containing only a long comment is distracting.
    " Because we only care about the code.
    if !get(g:, 'in_goyo_mode', 0) || &ft is# 'markdown'
        return 1
    endif
    let cml = matchstr(&l:cms, '\S*\ze\s*%s')
    " note that we allow opening numbered folds (because usually those can contain code)
    let fmr = '\%(' .. split(&l:fmr, ',')->join('\|') .. '\)'
    return getline('.') !~# '^\s*\V' .. escape(cml, '\') .. '\m.*' .. fmr .. '$'
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
            if new != 0 | exe 'norm! ' .. new .. "\<c-y>" | endif
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
            if new != 0 | exe 'norm! ' .. new .. "\<c-y>" | endif
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

fu s:conceallevel(enable) abort "{{{2
    if a:enable
        let &l:cole = 0
    else
        " Why toggling between `0` and `2`, instead of `0` and `3` like everywhere else?{{{
        "
        " In a markdown file, we want to see `cchar`.
        " For example, it's  useful to see a marker denoting  a concealed answer
        " to a question.
        " It could also be useful to pretty-print some logical/math symbols.
        "}}}
        let &l:cole = &ft is# 'markdown' ? 2 : 3
    endif
    echo '[conceallevel] ' .. &l:cole
endfu

fu s:edit_help_file(allow) "{{{2
    if &ft isnot# 'help' | return | endif

    if a:allow && &bt is# 'help'
        setl ma noro bt=

        nno <buffer><nowait><silent> <cr> 80<bar>

        let keys =<< trim END
            p
            q
            u
        END
        for key in keys
            exe 'sil unmap <buffer> ' .. key
        endfor

        for pat in map(keys, {_, v -> '|\s*exe\s*''[nx]unmap\s*<buffer>\s*' .. v .. "'"})
            let b:undo_ftplugin = substitute(b:undo_ftplugin, pat, '', 'g')
        endfor

        echo 'you CAN edit the file'

    elseif !a:allow && &bt isnot# 'help'
        " don't reload the buffer before setting `'bt'`; it would change the cwd (`vim-cwd`)
        setl noma ro bt=help
        " reload ftplugin
        edit
        echo 'you can NOT edit the file'
    endif
endfu

fu s:formatprg(scope) abort "{{{2
    if a:scope is# 'local' && &l:fp == ''
        let bufnr = bufnr('%')
        if has_key(s:fp_save, bufnr)
            let &l:fp = s:fp_save[bufnr]
            unlet! s:fp_save[bufnr]
        endif
    elseif a:scope is# 'global' && &l:fp != ''
        " save the local value on a per-buffer basis
        let s:fp_save[bufnr('%')] = &l:fp
        " clear the local value so that the global one is used
        set fp<
    endif
    echo '[formatprg] ' .. (!empty(&l:fp) ? &l:fp .. ' (local)' : &g:fp .. ' (global)')
endfu

fu s:hl_yanked_text(action) abort "{{{2
    if a:action is# 'is_active'
        return s:hl_yanked_text == 1
    elseif a:action is# 'enable'
        let s:hl_yanked_text = 1
    elseif a:action is# 'disable'
        let s:hl_yanked_text = 0
    endif
endfu

fu s:auto_hl_yanked_text() abort
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
            let text = join(text, "\n")
            let pat = '\%' .. line('.') .. 'l\%' .. virtcol('.') .. 'v\_.\{' .. strchars(text, 1) .. '}'
        elseif type is# 'V'
            let pat = '\%' .. line('.') .. 'l\_.*\%' .. (line('.') + len(text) - 1) .. 'l'
        elseif type =~# "\<c-v>" .. '\d\+'
            let width = matchstr(type, "\<c-v>" .. '\zs\d\+')
            let [line, vcol] = [line('.'), virtcol('.')]
            let pat = map(text, {i -> '\%' .. (line+i) .. 'l\%' .. vcol .. 'v.\{' .. width .. '}'})->join('\|')
        endif

        let id = matchadd('IncSearch', pat, 0, -1)
        call timer_start(s:HL_TIME, {-> exists('id') ? matchdelete(id) : ''})
    catch
        return s:Catch()
    endtry
endfu

fu s:lightness(less) abort "{{{2
    " increase or decrease the lightness
    if &bg is# 'light'
        " `g:seoul256_light_background` is the value to be used the *next* time we execute `:colo seoul256-light`
        let g:seoul256_light_background = get(g:, 'seoul256_light_background', g:seoul256_default_lightness)

        " We need to make `g:seoul256_light_background` cycle through `[252, 256]`.
        " How to make a number `n` cycle through `[a, a+1, ..., a+p]`?{{{
        "                                                ^
        "                                                `n` will always be somewhere in the middle
        "
        " Let's solve the issue for `a = 0`; i.e. let's make `n` cycle from 0 up to `p`.
        "
        " Special Case Solution:
        "
        "     ┌ new value of `n`
        "     │     ┌ old value of `n`
        "     │     │
        "     n2 = (n1 + 1) % (p + 1)
        "           ├────┘  ├───────┘
        "           │       └ but don't go above `p`
        "           │         read this as:  “p+1 is off-limit”
        "           │
        "           └ increment
        "
        " To use this solution, we need to find a link between the problem we've
        " just solved and our original problem.
        " In the latter, what cycles between 0 and `p`?: the distance between `a` and `n`.
        "
        " General Solution:
        "
        "     ┌ old distance between `n` and `a`
        "     │     ┌ new distance
        "     │     │
        "     d2 = (d1 + 1) % (p + 1)
        "
        "     ⇔ d2 = (d1 + 1) % (p + 1)
        "     ⇔ n2 - a = (n1 - a + 1) % (p + 1)
        "
        "            ┌ final formula
        "            ├────────────────────────┐
        "     ⇔ n2 = (n1 - a + 1) % (p + 1) + a
        "             ├────────┘  ├───────┘ ├─┘
        "             │           │         └ we want the distance from 0, not from `a`; so add `a`
        "             │           └ but don't go too far
        "             └ move away (+ 1) from `a` (n1 - a)
        "}}}
        let g:seoul256_light_background = a:less
            \ ? 256 - (256 - g:seoul256_light_background + 1) % (4 + 1)
            \ : (g:seoul256_light_background - 252 + 1) % (4 + 1) + 252

        " update colorscheme
        colo seoul256-light
        " get info to display in a message
        let level = g:seoul256_light_background - 252 + 1

    else
        " `g:seoul256_background` is the value to be used the *next* time we execute `:colo seoul256`
        let g:seoul256_background = get(g:, 'seoul256_background', 237)

        " We need to make `g:seoul256_background` cycle through `[233, 239]`.
        " How to make a number cycle through `[a+p, a+p-1, ..., a]`?{{{
        "
        " We want to cycle from `a + p` down to `a`.
        "
        " Let's use the formula `(d + 1) % (p + 1)` to update the *distance* between `n` and `a+p`:
        "
        "               d2 = (d1 + 1) % (p + 1)
        "     ⇔ a + p - n2 = (a + p - n1 + 1) % (p + 1)
        "
        "            ┌ final formula
        "            ├────────────────────────────────┐
        "     ⇔ n2 = a + p - (a + p - n1 + 1) % (p + 1)
        "            ├───┘    ├────────────┘  ├───────┘
        "            │        │               └ but don't go too far
        "            │        │
        "            │        └ move away (+ 1) from `a + p` (a + p - n1)
        "            │
        "            └ we want the distance from 0, not from `a + p`, so add `a + p`
        "}}}
        let g:seoul256_background = a:less
            \ ? 239 - (239 - g:seoul256_background + 1) % (6 + 1)
            \ : (g:seoul256_background - 233 + 1) % (6 + 1) + 233

        colo seoul256
        let level = g:seoul256_background - 233 + 1
    endif

    call timer_start(0, {-> execute('echo "[lightness]"' .. level, '')})
endfu

fu s:matchparen(enable) abort "{{{2
    if !exists('g:matchup_matchparen_enabled')
        echohl ErrorMsg
        echo 'matchparen module of matchup plugin not enabled'
        echohl NONE
        return
    endif

    if a:enable && !g:matchup_matchparen_enabled
        " Why `silent!`?{{{
        "
        " If an error is raised, `abort` would make the function sourcing this file stop.
        " We want the function to process all the code.
        "}}}
        sil! au! my_dummy_autocmds
        sil! aug! my_dummy_autocmds
        noa DoMatchParen
    elseif !a:enable && g:matchup_matchparen_enabled
        " Where is `:NoMatchParen` defined?{{{
        "
        " By default, in `$VIMRUNTIME/plugin/matchparen.vim`
        " But  we use  `vim-matchup` which  redefines  this command  as well  as
        " `:DoMatchParen` in `~/.vim/plugged/vim-matchup/plugin/matchup.vim`.
        "}}}
        " Do I need to preserve {{{
        "}}}
        "   the current/previous window?{{{
        "
        " Not if you use `vim-matchup`.
        " But you would probably need to  preserve them, if you used the default
        " matchparen plugin.
        "}}}
        "   the height of the windows, if some of them are squashed?{{{
        "
        " Same answer as previously.
        "}}}
        NoMatchParen
        call plugin#matchparen#install_dummy_autocmds()
    endif
    echo '[matchparen] ' .. (g:matchup_matchparen_enabled ? 'ON' : 'OFF')
endfu

fu s:scrollbind(enable) abort "{{{2
    let winid = win_getid()
    if a:enable && !&l:scb
        let s:scb_save[winid] = {'crb': &l:crb, 'cul': &l:cul, 'fen': &l:fen}
        setl scb crb cul nofen
        " not necessary  because we already set `'crb'` which  seems to have the
        " same effect, but it doesn't harm
        syncbind
    elseif !a:enable && &l:scb
        setl noscb
        if has_key(s:scb_save, winid)
            let &l:crb = get(s:scb_save[winid], 'crb', &l:crb)
            let &l:cul = get(s:scb_save[winid], 'cul', &l:cul)
            let &l:fen = get(s:scb_save[winid], 'fen', &l:fen)
            unlet! s:scb_save[winid]
        endif
    endif
endfu

fu s:showbreak(enable) abort "{{{2
    if a:enable
        setl sbr=↪
    elseif !a:enable
        set sbr<
    endif
endfu

fu s:synmaxcol(enable) abort "{{{2
    let bufnr = bufnr('%')
    if a:enable && &l:smc != s:SMC_BIG
        let s:smc_save[bufnr] = &l:smc
        let &l:smc = s:SMC_BIG
    elseif !a:enable && &l:smc == s:SMC_BIG
        if has_key(s:smc_save, bufnr)
            let &l:smc = s:smc_save[bufnr]
            unlet! s:smc_save[bufnr]
        endif
    endif
endfu

fu s:virtualedit(enable) abort "{{{2
    if a:enable
        set ve=all
    else
        let &ve = get(g:, 'orig_virtualedit', &ve)
    endif
endfu

fu s:nowrapscan(enable) abort "{{{2
    " Why do you inspect `'wrapscan'` instead of `'whichwrap'`?{{{
    "
    " Well, I think we  need to choose one of them;  can't inspect both, because
    " we could be in an unexpected state  where one of the option has been reset
    " manually (or by another plugin) but not the other.
    "
    " And we can't choose `'wrapscan'`.
    " If the  latter was reset  manually, the function  would fail to  toggle it
    " back on.
    "}}}
    if a:enable && &ws
        " Why clearing `'whichwrap'` too?{{{
        "
        " It can cause the same issue as `'wrapscan'`.
        " To stop, a recursive macro may need an error to be raised; however:
        "
        "    - this error may be triggered by an `h` or `l` motion
        "    - `'whichwrap'` suppresses this error if its value contains `h` or `l`
        "}}}
        let s:whichwrap_save = &whichwrap
        set nowrapscan whichwrap=
    elseif !a:enable && !&ws
        if exists('s:whichwrap_save')
            let &whichwrap = s:whichwrap_save
            unlet! s:whichwrap_save
        endif
        set wrapscan
    endif
endfu
" }}}1

" Mappings {{{1
" 2 "{{{2

call s:toggle_settings('P', 'previewwindow')
call s:toggle_settings('h', 'hlsearch')
call s:toggle_settings('i', 'list')
call s:toggle_settings('w', 'wrap')

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

" it's useful to temporarily disable `'wrapscan'` before executing a recursive macro,
" to be sure it's not stuck in an infinite loop
call s:toggle_settings(
    \ 'W',
    \ 'call <sid>nowrapscan(1)',
    \ 'call <sid>nowrapscan(0)',
    \ '&ws == 0',
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
    \ 'split(&l:nf, ",")->index("alpha") >= 0',
    \ )

call s:toggle_settings(
    \ 'b',
    \ 'call <sid>showbreak(1)',
    \ 'call <sid>showbreak(0)',
    \ '&l:sbr != ""',
    \ )

" Note: The conceal level is not a boolean state.{{{
"
" `'cole'` can have 4 different values.
" But it doesn't cause any issue, because we still treat it as a boolean option.
" We are only interested in 2 levels: 0 and 3 (or 2 in a markdown file).
"}}}
call s:toggle_settings(
    \ 'c',
    \ 'call <sid>conceallevel(1)',
    \ 'call <sid>conceallevel(0)',
    \ '&l:cole == 0',
    \ )

call s:toggle_settings(
    \ 'd',
    \ 'diffthis',
    \ 'diffoff <bar> norm! zv',
    \ '&l:diff',
    \ )

call s:toggle_settings(
    \ 'e',
    \ 'call <sid>edit_help_file(1)',
    \ 'call <sid>edit_help_file(0)',
    \ '&bt == ""',
    \ )

" Note: The lightness is not a boolean state.{{{
"
" So the numeric argument passed to  `s:lightness()` has not the same meaning as
" in other similar mappings.
"
" For  example, in  `call <sid>matchparen(1)`,  the `1`  stands for  the enabled
" state of the matchparen plugin.
" But here, `1` simply means "less lightness", and `0` means "more lightness".
"
" That's also why we just write `1` as the final argument passed to `s:toggle_settings()`.
" We can't  come up  with an  expression describing  the enabled  state, because
" there is no such thing as an enabled state.
"
" ---
"
" This implies that `col` doesn't work as with other settings.
" It doesn't toggle anything; it just increases the lightness.
"}}}
call s:toggle_settings(
    \ 'l',
    \ 'call <sid>lightness(1)',
    \ 'call <sid>lightness(0)',
    \ '1',
    \ )

call s:toggle_settings(
    \ 'm',
    \ 'call <sid>synmaxcol(1)',
    \ 'call <sid>synmaxcol(0)',
    \ '&l:smc == ' .. s:SMC_BIG,
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
"             \   '00' : 'setl nu | setl rnu',
"             \   '11' : 'setl nornu',
"             \   '01' : 'setl nonu',
"             \   '10' : 'setl nonu | setl nornu',
"             \ }[&l:nu .. &l:rnu]
"     endfu
"}}}
call s:toggle_settings(
    \ 'n',
    \ 'setl nu',
    \ 'setl nonu',
    \ '&l:nu',
    \ )

call s:toggle_settings(
    \ 'p',
    \ 'call <sid>matchparen(1)',
    \ 'call <sid>matchparen(0)',
    \ 'get(g:, "matchup_matchparen_enabled", 0)',
    \ )

" `gq`  is currently  used to  format comments,  but it  can also  be useful  to
" execute formatting tools such as js-beautify in html/css/js files.
call s:toggle_settings(
    \ 'q',
    \ 'call <sid>formatprg("local")',
    \ 'call <sid>formatprg("global")',
    \ '&l:fp != ""',
    \ )

call s:toggle_settings(
    \ 'r',
    \ 'call <sid>scrollbind(1)',
    \ 'call <sid>scrollbind(0)',
    \ '&l:scb',
    \ )

call s:toggle_settings(
    \ 's',
    \ 'setl spell"',
    \ 'setl nospell"',
    \ '&l:spell',
    \ )

call s:toggle_settings(
    \ 't',
    \ 'let b:foldtitle_full=1 <bar> redraw!',
    \ 'let b:foldtitle_full=0 <bar> redraw!',
    \ 'get(b:, "foldtitle_full", 0)',
    \ )

call s:toggle_settings(
    \ 'v',
    \ 'call <sid>virtualedit(1)',
    \ 'call <sid>virtualedit(0)',
    \ '&ve is# "all"',
    \ )

call s:toggle_settings(
    \ 'y',
    \ 'call <sid>hl_yanked_text("enable")',
    \ 'call <sid>hl_yanked_text("disable")',
    \ '<sid>hl_yanked_text("is_active")',
    \ )

" Vim uses `z` as a prefix to build all fold-related commands in normal mode.
call s:toggle_settings(
    \ 'z',
    \ 'call toggle_settings#auto_open_fold(1)',
    \ 'call toggle_settings#auto_open_fold(0)',
    \ 'maparg("j", "n", 0, 1)->get("rhs", "") =~# "move_and_open_fold"'
    \ )

