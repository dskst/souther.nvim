" Vim syntax file for the Souther language.

if exists("b:current_syntax")
  finish
endif

lua require("souther.syntax").apply()

let b:current_syntax = "souther"
