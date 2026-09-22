" Vim syntax file for the Souther language.
"
" This is a fallback, not the main event. Highlighting comes from
" souther-lsp's semantic tokens, which know what an identifier actually is;
" they are applied at a higher priority and win wherever they land. This file
" covers the gaps the server cannot: the seconds before it attaches (it is a
" JVM process, so that is measurable), buffers it never attaches to at all
" (diff views, Telescope previews, `:help` examples), and machines where
" souther is not installed.
"
" Keep it in step with the generated TextMate grammar at
" souther-compiler/src/main/resources/souther/compiler/highlight/souther.tmLanguage.json.

if exists("b:current_syntax")
  finish
endif

syn case match

syn keyword southerDeclaration behavior data exposing import let module
syn keyword southerConditional if then else match guard unreachable
syn keyword southerKeyword as constructs ensures invariant with
syn match   southerKeyword "\<depends\>\%(\s\+\<on\>\)\?"
syn keyword southerBoolean false true

" `example`, `examples for` and `fake` are contextual keywords: they are only
" keywords as the first word of a top-level form, which is why `example.core`
" stays a module name. The server reports them as plain identifiers today
" (souther-lsp classifies them as `variable`), so this is also the one place
" where the fallback is visibly better than the semantic tokens.
syn match southerDeclaration "^\s*\%(example\|fake\)\>"
syn match southerDeclaration "^\s*examples\>" nextgroup=southerExamplesFor skipwhite
syn match southerExamplesFor "\<for\>" contained

syn match southerType "\<\%(Bool\|Date\|DateTime\|Decimal\|Instant\|Int\|List\|Map\|Option\|Set\|String\|Time\)\>"
syn match southerTypeVar "'\k\+"

syn match southerNumber "\<\d\+\%(\.\d\+\)\?m\>"
syn match southerNumber "\<\d\+\>"

syn match southerOperator "\.\.\.\|<?>\|>->\|&&\|++\|->\|/=\|<=\|==\|>=\||>\|||\|[*+/<=>?|-]"

syn region southerString start=+"+ skip=+\\\\\|\\"+ end=+"+ end=+$+ contains=southerEscape,southerEscapeError
syn match southerEscape +\\["\\nrt]+ contained
syn match southerEscapeError +\\.+ contained

syn match southerComment "//.*$" contains=@Spell

hi def link southerDeclaration  Keyword
hi def link southerConditional  Conditional
hi def link southerKeyword      Keyword
hi def link southerExamplesFor Keyword
hi def link southerBoolean      Boolean
hi def link southerType         Type
hi def link southerTypeVar      Identifier
hi def link southerNumber       Number
hi def link southerOperator     Operator
hi def link southerString       String
hi def link southerEscape       SpecialChar
hi def link southerEscapeError  Error
hi def link southerComment      Comment

let b:current_syntax = "souther"
