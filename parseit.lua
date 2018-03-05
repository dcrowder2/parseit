--[[
parseit.lua
Dakota Crowder
Assignment 4
CSCE 331 Programming Language Concepts
Using code from
https://projects.cs.uaf.edu/redmine/projects/cs331_2018_01/repository/changes/assn4_code.txt?rev=master
https://projects.cs.uaf.edu/redmine/projects/cs331_2018_01/repository/changes/userdparser4.lua?rev=master
--]]

local parseit = {}
lexit = require "lexit"

-- Variables

-- For lexit iteration
local iter          -- Iterator returned by lexit.lex
local state         -- State for above iterator (maybe not used)
local lexit_out_s   -- Return value #1 from above iterator
local lexit_out_c   -- Return value #2 from above iterator

-- For current lexeme
local lexstr = ""   -- String form of current lexeme
local lexcat = 0    -- Category of current lexeme:
                    --  one of categories below, or 0 for past the end
-- Symbolic Constants for AST

local STMT_LIST   = 1
local INPUT_STMT  = 2
local PRINT_STMT  = 3
local FUNC_STMT   = 4
local CALL_FUNC   = 5
local IF_STMT     = 6
local WHILE_STMT  = 7
local ASSN_STMT   = 8
local CR_OUT      = 9
local STRLIT_OUT  = 10
local BIN_OP      = 11
local UN_OP       = 12
local NUMLIT_VAL  = 13
local BOOLLIT_VAL = 14
local SIMPLE_VAR  = 15
local ARRAY_VAR   = 16


-- Utility Functions

-- advance
-- Go to next lexeme and load it into lexstr, lexcat.
-- Should be called once before any parsing is done.
-- Function init must be called before this function is called.
local function advance()
  -- Advance the iterator
  lexit_out_s, lexit_out_c = iter(state, lexit_out_s)

  -- If we're not past the end, copy current lexeme into vars
  if lexit_out_s ~= nil then
    lexstr, lexcat = lexit_out_s, lexit_out_c
    if lexcat == lexit.ID or lexcat == lexit.NUMLIT or lexstr == ")" or lexstr == "true" or lexstr == "false" then
      lexit.preferOp()
    end
  else
    lexstr, lexcat = "", 0
  end
end


-- init
-- Initial call. Sets input for parsing functions.
local function init(prog)
  iter, state, lexit_out_s = lexit.lex(prog)
  advance()
end


-- atEnd
-- Return true if pos has reached end of input.
-- Function init must be called before this function is called.
local function atEnd()
  return lexcat == 0
end


-- matchString
-- Given string, see if current lexeme string form is equal to it. If
-- so, then advance to next lexeme & return true. If not, then do not
-- advance, return false.
-- Function init must be called before this function is called.
local function matchString(s)
  if lexstr == s then
    advance()
    return true
  else
    return false
  end
end


-- matchCat
-- Given lexeme category (integer), see if current lexeme category is
-- equal to it. If so, then advance to next lexeme & return true. If
-- not, then do not advance, return false.
-- Function init must be called before this function is called.
local function matchCat(c)
  if lexcat == c then
    advance()
    return true
  else
    return false
  end
end

-- Primary Function for Client Code

-- parse
-- Given program, initialize parser and call parsing function for start
-- symbol. Returns pair of booleans & AST. First boolean indicates
-- successful parse and not. Second boolean indicates whether the parser
-- reached the end of the input or not. AST is only valid if first
-- boolean is true.
function parseit.parse(prog)
  -- Initialization
  init(prog)

  -- Get results from parsing
  local good, ast = parse_program()  -- Parse start symbol
  local done = atEnd()

  -- And return them
  return good, done, ast
end

-- From the parsing functions:


-- parse_program
-- Parsing function for nonterminal "program".
-- Function init must be called before this function is called.
function parse_program()
  local good, ast

  good, ast = parse_stmt_list()
  return good, ast
end


-- parse_stmt_list
-- Parsing function for nonterminal "stmt_list".
-- Function init must be called before this function is called.
function parse_stmt_list()
  local good, ast, newast

  ast = { STMT_LIST }
  while true do
    if lexstr ~= "input"
      and lexstr ~= "print"
      and lexstr ~= "func"
      and lexstr ~= "call"
      and lexstr ~= "if"
      and lexstr ~= "while"
      and lexcat ~= lexit.ID then
        return true, ast
    end

    good, newast = parse_statement()
    if not good then
        return false, nil
    end

    table.insert(ast, newast)
  end
  return true, ast
end


-- parse_statement
-- Parsing function for nonterminal "statement"
-- Function init must be called before this function is called.
function parse_statement()
  local good, ast1, ast2, savelex

  if matchString("input") then
    good, ast1 = parse_lvalue()
    if not good then
        return false, nil
    end

    return true, { INPUT_STMT, ast1 }
  
  elseif matchString("print") then
    good, ast1 = parse_print_arg()
    if not good then
        return false, nil
    end

    ast2 = { PRINT_STMT, ast1 }

    while true do
        if not matchString(";") then
            break
        end

        good, ast1 = parse_print_arg()
        if not good then
            return false, nil
        end

        table.insert(ast2, ast1)
    end

    return true, ast2

  elseif matchString("func") then
    savelex = lexstr
    if not matchCat(lexit.ID) then
        return false, nil
    end

    good, ast1 = parse_stmt_list()
    if not good then
        return false, nil
    end

    if not matchString("end") then
        return false, nil
    end
    return true, {FUNC_STMT, savelex, ast1}

  elseif matchString("call") then
    savestring = lexstr
    if not matchCat(lexit.ID) then
        return false, nil
    end
    return true, {CALL_FUNC, savestring}

  elseif matchString("if") then
    good, ast1 = parse_expr()
    if not good then
        return false, nil
    end

    good, ast2 = parse_stmt_list()
    if not good then
        return false, nil
    end

    ast1 = {IF_STMT, ast1, ast2}
    while true do
      if not matchString("elseif") then
        break
      end
      good, ast2 = parse_expr()
      if not good then
          return false, nil
      end
      table.insert(ast1, ast2)
      good, ast2 = parse_stmt_list()
      if not good then
          return false, nil
      end
      table.insert(ast1, ast2)
    end
    if  matchString("else") then
      good, ast2 = parse_stmt_list()
      if not good then
          return false, nil
      end
      table.insert(ast1, ast2)
    end

    if not matchString("end") then
      return false, nil
    end

    return true, ast1

  elseif matchString("while") then
    good, ast1 = parse_expr()
    if not good then
      return false, nil
    end

    good, ast2 = parse_stmt_list()
    if not good then
      return false, nil
    end

    if not matchString("end") then
      return false, nil
    end
    return true, {WHILE_STMT, ast1, ast2}
  end
  --Parsing Assign statements
  good, ast1 = parse_lvalue()
  if not good then
    return false, nil
  end
  if not matchString("=") then
    return false, nil
  end
  good, ast2 = parse_expr()
  if not good then
    return false, nil
  end
  return true, {ASSN_STMT, ast1, ast2}

end

-- parse_expr
-- Parsing function for nonterminal "expression"
-- Function init must be called before this function is called.
function parse_expr()
  local good, ast, ast2, saveop
  good, ast = parse_comp_expr()
  if not good then
    return false, nil
  end
  while true do
    saveop = lexstr
    if not matchString("&&") and not matchString("||") then
      return true, ast
    end
    good, ast2 = parse_comp_expr()
    if not good then
      return false, nil
    end
    ast = {{BIN_OP, saveop}, ast, ast2}
  end
end

-- parse_comp_expr
-- Parsing function for nonterminal "comparision expression"
-- Function init must be called before this function is called.
function parse_comp_expr()
  local good, ast, saveop, ast2
  if matchString("!") then
    good, ast = parse_comp_expr()
    if not good then
      return false, nil
    end
    return true, {{UN_OP, "!"}, ast}
  end
  good, ast = parse_arith_expr()
  if not good then
    return false, nil
  end
  while true do
    saveop = lexstr
    if not matchString("==") and not matchString("!=") and not matchString("<")
    and not matchString("<=") and not matchString(">") and not matchString(">=") then
      return true, ast
    end
    good, ast2 = parse_arith_expr()
    if not good then
      return false, nil
    end
    ast = {{BIN_OP, saveop}, ast, ast2}
  end
end

-- parse_arith_expr
-- Parsing function for nonterminal "arithmatic expression"
-- Function init must be called before this function is called.
function parse_arith_expr()
  local good, ast, ast2, saveop
  good, ast = parse_term()
  if not good then
    return false, nil
  end
  while true do
    saveop = lexstr
    if not matchString("+") and not matchString("-") then
      return true, ast
    end
    good, ast2 = parse_term()
    if not good then
      return false, nil
    end
    ast = {{BIN_OP, saveop}, ast, ast2}
  end
end
-- parse_term
-- Parsing function for nonterminal "term"
-- Function init must be called before this function is called.
function parse_term()
  local good, ast, saveop, newast

  good, ast = parse_factor()
  if not good then
      return false, nil
  end

  while true do
    saveop = lexstr
    if not matchString("*") and not matchString("/") and not matchString("%") then
        return true, ast
    end

    good, newast = parse_factor()
    if not good then
        return false, nil
    end

    ast = { { BIN_OP, saveop }, ast, newast }
  end
end


-- parse_factor
-- Parsing function for nonterminal "factor".
-- Function init must be called before this function is called.
function parse_factor()
  local savelex, good, ast

  savelex = lexstr
  if matchCat(lexit.NUMLIT) then
      return true, { NUMLIT_VAL, savelex }
  elseif matchString("(") then
      good, ast = parse_expr()
      if not good then
          return false, nil
      end

      if not matchString(")") then
          return false, nil
      end

      return true, ast
  elseif matchString("call") then
    savelex = lexstr
    if matchCat(lexit.ID) then
      return true, {CALL_FUNC, savelex}
    end
  elseif matchString("+") or matchString("-") then
    good, ast = parse_factor()
    if not good then
      return false, nil
    end
    return true, {{UN_OP, savelex}, ast}
  elseif matchString("true") or matchString("false") then
    return true, {BOOLLIT_VAL, savelex}
  else
    good, ast = parse_lvalue()
    if not good then
      return false, nil
    end
    return true, ast
  end
end
-- parse_lvalue
-- Parsing function for nonterminal "lvalue"
-- Function init must be called before this function is called.
function parse_lvalue()
  local good, ast, id
  id = lexstr
  if not matchCat(lexit.ID) then
    return false, nil
  end
  if not matchString("[") then
    return true, {SIMPLE_VAR, id}
  end

  good, ast = parse_expr()
  if not good then
    return false, nil
  end

  if not matchString("]") then
    return false, nil
  end
  return true, {ARRAY_VAR, id, ast}
end
-- parse_print_arg
-- Parsing function for nonterminal "print arguments"
-- Function init must be called before this function is called.
function parse_print_arg()
  local good, ast, savelex
  if matchString("cr") then
    return true, {CR_OUT}
  end
  savelex = lexstr
  if matchCat(lexit.STRLIT) then
    return true, {STRLIT_OUT, savelex}
  end
  good, ast = parse_expr()
  if not good then
    return false, nil
  end
  return true, ast
end
return parseit
