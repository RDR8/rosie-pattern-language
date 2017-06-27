-- -*- Mode: Lua; -*-                                                                             
--
-- trace.lua
--
-- © Copyright IBM Corporation 2017.
-- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
-- AUTHOR: Jamie A. Jennings


local ast = require "ast"
local common = require "common"
local pattern = common.pattern
local engine_module = require "engine_module"
local engine = engine_module.engine
local rplx = engine_module.rplx

local trace = {}

---------------------------------------------------------------------------------------------------
-- Print a trace
---------------------------------------------------------------------------------------------------

local function tab(n)
   return string.rep(" ", n)
end

function trace.tostring(t, indent)
   indent = indent or 0
   local delta = 2
   assert(t.ast)
   local str = tab(indent) .. "Expression: " .. ast.tostring(t.ast) .. "\n"
   indent = indent + 2
   str = str .. tab(indent) .. "Looking at: |" .. t.input:sub(t.start) .. "| (input pos = "
   str = str .. tostring(t.start) .. ")\n"
   str = str .. tab(indent)
   if t.match then
      str = str .. "Matched " .. tostring(t.nextpos - t.start) .. " chars"
   else
      str = str .. "No match"
   end
   str = str .. "\n"
   for _, sub in ipairs(t.subs or {}) do
      str = str .. trace.tostring(sub, indent+delta)
   end
   return str
end
      
---------------------------------------------------------------------------------------------------
-- Trace functions for each expression type
---------------------------------------------------------------------------------------------------

local expression;

local function sequence(e, a, input, start, expected, nextpos)
   local matches = {}
   local nextstart = start
   for _, exp in ipairs(a.exps) do
      local result = expression(e, exp, input, nextstart)
      table.insert(matches, result)
      if not result.match then break
      else nextstart = result.nextpos; end
   end -- for
   if (#matches==#a.exps) and (matches[#matches].match) then
      assert(expected, "sequence match differs from expected")
      local last = matches[#matches]
      assert(last.nextpos==nextpos, "sequence nextpos differs from expected")
      return {match=expected, nextpos=nextpos, ast=a, subs=matches, input=input, start=start}
   else
      assert(not expected, "sequence non-match differs from expected")
      return {match=expected, nextpos=nextpos, ast=a, subs=matches, input=input, start=start}
   end
end

local function choice(e, a, input, start, expected, nextpos)
   local matches = {}
   for _, exp in ipairs(a.exps) do
      local result = expression(e, exp, input, start)
      table.insert(matches, result)
      if result.match then break; end
   end -- for
   local last = matches[#matches]
   if (last.match) then
      assert(expected, "choice match differs from expected")
      assert(last.nextpos==nextpos, "choice nextpos differs from expected")
      return {match=expected, nextpos=nextpos, ast=a, subs=matches, input=input, start=start}
   else
      assert(not expected, "choice non-match differs from expected")
      return {match=expected, nextpos=nextpos, ast=a, subs=matches, input=input, start=start}
   end
end

-- FUTURE: A qualified reference to a separately compiled module may not have an AST available
-- for debugging (unless it was compiled with debugging enabled).  N.B. Currently, when the AST
-- field of a pattern is false, the pattern is a built-in.  This must change.
local function ref(e, a, input, start, expected, nextpos)
   local pat = a.pat
   if not pat.ast then
      -- In a trace, a reference has one sub (or none, if it is built-in)
      return {match=expected, nextpos=nextpos, ast=a, input=input, start=start}
   else
      local result = expression(e, pat.ast, input, start)
      if expected then
	 assert(result.match, "reference match differs from expected")
	 assert(nextpos==result.nextpos, "reference nextpos differs from expected")
      else
	 assert(not result.match)
      end
      -- In a trace, a reference has one sub (or none, if it is built-in)
      return {match=expected, nextpos=nextpos, ast=a, subs={result}, input=input, start=start}
   end
end

-- Note: 'atleast' implements * when a.min==0
local function atleast(e, a, input, start, expected, nextpos)
   local matches = {}
   local nextstart = start
   assert(type(a.min)=="number")
   while true do
      local result = expression(e, a.exp, input, nextstart)
      table.insert(matches, result)
      if not result.match then break
      else nextstart = result.nextpos; end
   end -- while
   local last = matches[#matches]
   if (#matches > a.min) or (#matches==a.min and last.match) then
      assert(expected, "atleast match differs from expected")
      assert(nextstart==nextpos, "atleast nextpos differs from expected")
      return {match=expected, nextpos=nextpos, ast=a, subs=matches, input=input, start=start}
   else
      assert(not expected, "atleast non-match differs from expected")
      return {match=expected, nextpos=nextpos, ast=a, subs=matches, input=input, start=start}
   end
end

-- 'atmost' always succeeds, because it matches from 0 to a.max copies of exp, and it stops trying
-- to match after it matches a.max times.
local function atmost(e, a, input, start, expected, nextpos)
   local matches = {}
   local nextstart = start
   assert(type(a.max)=="number")
   for i = 1, a.max do
      local result = expression(e, a.exp, input, nextstart)
      table.insert(matches, result)
      if not result.match then break
      else nextstart = result.nextpos; end
   end -- while
   local last = matches[#matches]
   assert(expected, "atmost match differs from expected")
   assert(last.nextpos==nextpos, "atmost nextpos differs from expected")
   return {match=expected, nextpos=nextpos, ast=a, subs=matches, input=input, start=start}
end

function expression(e, a, input, start)
   local pat = a.pat
   assert(pattern.is(pat), "no pattern stored in ast node " .. tostring(a))
   local m, nextpos = pat.peg:rmatch(input, start)
   if m and (#m > 0) then m = lpeg.decode(m); end
   print("***", a, start, m, nextpos)
   
   if ast.literal.is(a) then
      return {match=m, nextpos=nextpos, ast=a, input=input, start=start}
   elseif ast.sequence.is(a) then
      return sequence(e, a, input, start, m, nextpos)
   elseif ast.choice.is(a) then
      return choice(e, a, input, start, m, nextpos)
   elseif ast.ref.is(a) then
      return ref(e, a, input, start, m, nextpos)
   elseif ast.atleast.is(a) then
      return atleast(e, a, input, start, m, nextpos)
   elseif ast.atmost.is(a) then
      return atmost(e, a, input, start, m, nextpos)
   else
      error("Internal error: invalid ast type in eval expression: " .. tostring(a))
   end
end

function trace.expression(r, input, start)
   assert(rplx.is(r))
   assert(engine.is(r._engine))
   assert(pattern.is(r._pattern))
   assert(type(input)=="string")
   assert(type(start)=="number")
   local a = r._pattern.ast
   assert(a, "no ast stored for pattern")
   return expression(r._engine, a, input, start)
end

return trace


