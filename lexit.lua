--[[
lexit.lua
Dakota Crowder
2018 February 20
Assignment 3 CSCE 331 Programming Language Concepts
using modified code from program described below
edits commented with "EDIT: " to describe changes made
--]]

-- lexit.lua
-- Glenn G. Chappell
-- 6 Feb 2018
-- Updated: 9 Feb 2018
--
-- For CS F331 / CSCE A331 Spring 2018
-- In-Class lexit Module

-- Usage:
--
--    program = "print a+b;"  -- program to lex
--    for lexstr, cat in lexit.lex(program) do
--        -- lexstr is the string form of a lexeme.
--        -- cat is a number representing the lexeme category.
--        --  It can be used as an index for array lexit.catnames
--    end


-- *********************************************************************
-- Module Table Initialization
-- *********************************************************************


local lexit = {}  -- Our module; members are added below


-- *********************************************************************
-- Public Constants
-- *********************************************************************


-- Numeric constants representing lexeme categories
lexit.KEY = 1
lexit.ID = 2
lexit.NUMLIT = 3
lexit.STRLIT = 4 --EDIT: added STRLIT, changed numerics appropriately
lexit.OP = 5
lexit.PUNCT = 6
lexit.MAL = 7


-- catnames
-- Array of names of lexeme categories.
-- Human-readable strings. Indices are above numeric constants.
lexit.catnames = {
    "Keyword",
    "Identifier",
    "NumericLiteral",
    "StringLiteral", --EDIT: added name for new category
    "Operator",
    "Punctuation",
    "Malformed",
}


-- *********************************************************************
-- Kind-of-Character Functions
-- *********************************************************************

-- All functions return false when given a string whose length is not
-- exactly 1.


-- isLetter
-- Returns true if string c is a letter character, false otherwise.
local function isLetter(c)
    if c:len() ~= 1 then
        return false
    elseif c >= "A" and c <= "Z" then
        return true
    elseif c >= "a" and c <= "z" then
        return true
    else
        return false
    end
end


-- isDigit
-- Returns true if string c is a digit character, false otherwise.
local function isDigit(c)
    if c:len() ~= 1 then
        return false
    elseif c >= "0" and c <= "9" then
        return true
    else
        return false
    end
end


-- isWhitespace
-- Returns true if string c is a whitespace character, false otherwise.
local function isWhitespace(c)
    if c:len() ~= 1 then
        return false
    elseif c == " " or c == "\t" or c == "\n" or c == "\r"
      or c == "\f" then
        return true
    else
        return false
    end
end


-- isIllegal
-- Returns true if string c is an illegal character, false otherwise.
local function isIllegal(c)
    if c:len() ~= 1 then
        return false
    elseif isWhitespace(c) then
        return false
    elseif c >= " " and c <= "~" then
        return false
    else
        return true
    end
end

local preferOpFlag = false--EDIT: added preferOpFlag and preferOp

function lexit.preferOp()
    preferOpFlag = true
end

-- *********************************************************************
-- The lexit
-- *********************************************************************


-- lex
-- Our lexit
-- Intended for use in a for-in loop:
--     for lexstr, cat in lexit.lex(program) do
-- Here, lexstr is the string form of a lexeme, and cat is a number
-- representing a lexeme category. (See Public Constants.)
function lexit.lex(program)
    -- ***** Variables (like class data members) *****

    local pos       -- Index of next character in program
                    -- INVARIANT: when getLexeme is called, pos is
                    --  EITHER the index of the first character of the
                    --  next lexeme OR program:len()+1
    local state     -- Current state for our state machine
    local ch        -- Current character
    local lexstr    -- The lexeme, so far
    local category  -- Category of lexeme, set when state set to DONE
    local handlers  -- Dispatch table; value created later

    -- ***** States *****

    local DONE = 0
    local START = 1
    local LETTER = 2
    local DIGIT = 3
    local EXPONENT = 4 --EDIT: replaced digdot with exponent, as digdot is malformed
    local PLUS = 5
    local MINUS = 6
    local EQUALS = 7
    local STRING = 8 --EDIT: added STRING

    -- ***** Character-Related Utility Functions *****

    -- currChar
    -- Return the current character, at index pos in program. Return
    -- value is a single-character string, or the empty string if pos is
    -- past the end.
    local function currChar()
        return program:sub(pos, pos)
    end

    -- nextChar
    -- Return the next character, at index pos+1 in program. Return
    -- value is a single-character string, or the empty string if pos+1
    -- is past the end.
    local function nextChar()
        return program:sub(pos+1, pos+1)
    end

    --EDIT: nextNextChar
    -- Return the nextNextChar, at inddex pos+2 in program. Return
    -- value is a single-character string, or the empty string if pos+1
    -- is past the end.
    local function nextNextChar()
        return program:sub(pos+2, pos+2)
    end

    -- drop1
    -- Move pos to the next character.
    local function drop1()
        pos = pos+1
    end

    -- add1
    -- Add the current character to the lexeme, moving pos to the next
    -- character.
    local function add1()
        lexstr = lexstr .. currChar()
        drop1()
    end

    -- skipWhitespace
    -- Skip whitespace and comments, moving pos to the beginning of
    -- the next lexeme, or to program:len()+1.
    local function skipWhitespace()
        while true do
            while isWhitespace(currChar()) do
                drop1()
            end

            if currChar() ~= "#" then  -- Comment? EDIT: Changed identifier for comments
                break
            end
            drop1()

            while true do
                if currChar() == "\n" then --EDIT: Changed ending identifier for comments
                    drop1()
                    break
                elseif currChar() == "" then  -- End of input?
                   return
                end
                drop1()
            end
        end
    end

    -- ***** State-Handler Functions *****

    -- A function with a name like handle_XYZ is the handler function
    -- for state XYZ

    local function handle_DONE()
        io.write("ERROR: 'DONE' state should not be handled\n")
        assert(0)
    end

    local function handle_START()
        if isIllegal(ch) then
            add1()
            state = DONE
            category = lexit.MAL
        elseif isLetter(ch) or ch == "_" then
            add1()
            state = LETTER
        elseif isDigit(ch) then
            add1()
            state = DIGIT
        elseif ch == "\"" or ch == "\'" then
            add1()
            state = STRING
        elseif ch == "+" then
            add1()
            if preferOpFlag then
                state = DONE
                category = lexit.OP
            else
                state = PLUS
            end
        elseif ch == "-" then
            add1()
            if preferOpFlag then --EDIT: added preferOpFlag for both + and -
                state = DONE
                category = lexit.OP
            else
                state = MINUS
            end
        elseif ch == "=" or ch == "!" or ch == "<" or ch == ">" then--EDIT: changed the handeling of OPs
            add1()
            state = EQUALS
        elseif (ch == "&" and nextChar() == "&") or (ch == "|" and nextChar() == "|") then
            add1()
            add1()
            state = DONE
            category = lexit.OP
        elseif ch == "*" or ch == "/" or  ch == "%" or ch == "[" or ch == "]"
              or ch == ";" then
            add1()
            state = DONE
            category = lexit.OP
        else
            add1()
            state = DONE
            category = lexit.PUNCT
        end
    end

    local function handle_LETTER()
        if isLetter(ch) or isDigit(ch) or ch == "_" then
            add1()
        else
            state = DONE
            if lexstr == "call" or lexstr == "cr" --EDIT: changed keywords
              or lexstr == "else" or lexstr == "elseif" or lexstr == "end"
              or lexstr == "false" or lexstr == "func" or lexstr == "if"
              or lexstr == "input" or lexstr == "print" or lexstr == "true"
              or lexstr == "while" then
                category = lexit.KEY
            else
                category = lexit.ID
            end
        end
    end

    local function handle_DIGIT()
        if isDigit(ch) then
            add1() --EDIT: Removed digdot
        elseif (ch == "e" or ch == "E") and (isDigit(nextChar()) or (nextChar() == "+" and isDigit(nextNextChar()))) then --EDIT: added check for exponent
            add1()
            add1()
            state = EXPONENT
        else
            state = DONE
            category = lexit.NUMLIT
        end
    end
-- removed digdot
    local function handle_PLUS()
        if isDigit(ch) then
            add1()
            state = DIGIT
        else --EDIT: removed digdot and "+" or "=" checker
            state = DONE
            category = lexit.OP
        end
    end

    local function handle_MINUS()
        if isDigit(ch) then
            add1()
            state = DIGIT
        else--EDIT: Removed digdot and "-" or "=" checker
            state = DONE
            category = lexit.OP
        end
    end

    local function handle_EQUALS()--EDIT: Now handles = or ! or > or <
        if ch == "=" then
            add1()
            state = DONE
            category = lexit.OP
        else
            state = DONE
            category = lexit.OP
        end
    end

    local function handle_EXPONENT()--EDIT: added handle_EXPONENT
        if isDigit(ch) then
            add1()
        else
            state = DONE
            category = lexit.NUMLIT
        end
    end

    local function handle_STRING()--EDIT: added handle_STRING

        if ch == string.sub(lexstr, 1, 1) then
            add1()
            state = DONE
            category = lexit.STRLIT
        elseif ch == "\n" then
            add1()
            state = DONE
            category = lexit.MAL
        elseif ch == "" then
            state = DONE
            category = lexit.MAL
        else
            add1()
        end
    end


    -- ***** Table of State-Handler Functions *****

    handlers = {
        [DONE]=handle_DONE,
        [START]=handle_START,
        [LETTER]=handle_LETTER,
        [DIGIT]=handle_DIGIT,
        [EXPONENT]=handle_EXPONENT,
        [PLUS]=handle_PLUS,
        [MINUS]=handle_MINUS,
        [EQUALS]=handle_EQUALS,
        [STRING]=handle_STRING,
    }

    -- ***** Iterator Function *****

    -- getLexeme
    -- Called each time through the for-in loop.
    -- Returns a pair: lexeme-string (string) and category (int), or
    -- nil, nil if no more lexemes.
    local function getLexeme(dummy1, dummy2)
        if pos > program:len() then
            preferOpFlag = false
            return nil, nil
        end
        lexstr = ""
        state = START
        while state ~= DONE do
            ch = currChar()
            handlers[state]()
        end

        skipWhitespace()
        preferOpFlag = false
        return lexstr, category
    end

    -- ***** Body of Function lex *****

    -- Initialize & return the iterator function
    pos = 1
    skipWhitespace()
    return getLexeme, nil, nil
end


-- *********************************************************************
-- Module Table Return
-- *********************************************************************


return lexit
