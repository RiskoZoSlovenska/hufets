--[[--
	Alright lemme figure out what I'm actually trying to do.

	Magic characters are %, -, &, /, ' ' (space) and |. ! is not magic, but
	may have magic behavior when not escaped. Any other character is non-magic.
	The magic character % makes any following character automatically non-magic.

	A "group" is a non-empty sequence of non-magic characters and/or the magic -
	characters.

	A non-magic character matches itself.
	'-' matches a sequence of alphanumeric characters.
	' ' matches a sequence of non-alphanumeric characters.
	Two or more groups separated by a '/' match any one of said groups.
	' & ' between two groups will match any characters between those two
	  groups, making sure that there is a non-alphanumeric character after the
	  first group and before the second group. The pattern will fail to parse if
	  & is not escaped and not padded by spaces on both sides.
	'|' anchors the string to the beginning or the end. The pattern will fail to
	  parse if | is anywhere else and is not escaped.

	Position captures are placed at the leftmost and rightmost boundary between
	a group and a space.
	By default, there must not be any alphanumeric characters on the sides of the
	pattern (almost like an implicit space). An explicit '-' can be used to
	disable this.
	By default, the pattern matches anywhere. To anchor the pattern to the
	beginning or end, use '|' on said (or both) sides.
	Additionally, all custom handling can be skipped by prepending '!'s to the
	beginning of the message. A single ! will take everything after it and
	compile it using the re module, but will still match anywhere. Two !s will
	disable the anywhere match as well.

	Caveats:
	One should be careful when using '-'s; if they are directly followed by a
	sequence of non-magics, they will fail to match if they find that sequence
	without matching themselves first. "a-b" will match "aab", but not "abb".
	The & is somewhat similar in this behavior.
	Remember that a space matches any non-alphanumeric character, including
	punctuation. This means that "a !b" will never match (since the ! will be
	consumed by the space in front of it). However, "a! b" will.
]]

local lpeg, re = require("lpeg"), require("re")

local P, B, V = lpeg.P, lpeg.B, lpeg.V
local Cp, Cc, Cf = lpeg.Cp, lpeg.Cc, lpeg.Cf



local function lazy(pat1, endPat)
	return P{ endPat + (pat1 * V(1)) }
end

local function andFold(a, b) return a * b end
local function orFold(a, b)  return a + b end

local function noEscP(str)
    return P((  string.gsub(str, "%%(.)", "%1")  ))
end


local esc   = P"%"
local space = P" "
local dash  = P"-"
local amp   = P"&"
local slash = P"/"
local anchor = P"|"

local magic = esc + space + dash + amp + slash + anchor
local nonmagic = (1 - magic) + (esc * 1)

local alnum = lpeg.locale().alnum
local other = 1 - alnum

local cpos = Cc(Cp())
local cspace = space * Cc(other^1)


local function makeArbitraryAndSeq(seqRet)
	-- return (alnum - seqRet)^1 * seqRet
	-- return alnum * P{ seqRet + alnum * V(1) }
	return alnum * lazy(alnum, seqRet)
end

local seq = nonmagic^1 / noEscP
local arbitrary = dash * Cc(alnum^1)
local arbitraryAndSeq = (dash * seq / makeArbitraryAndSeq)


local function makeBetween(a, b)
	local target = B(other) * b
    return a * other * (1 - target)^0 * target
end

local group = Cf((seq + arbitraryAndSeq + arbitrary)^1, andFold)
local multi = Cf(group * (slash * group)^0, orFold)
local between = multi * space * amp * space * multi / makeBetween

local component = between + multi + cspace

local frontImplicit = Cc(-B(alnum))
local backImplicit  = Cc(-#alnum  )

local endAnchor = ( anchor * Cc( other^0 * -P(1) ) )^-1

local body = Cf(frontImplicit * cpos * component^1 * cpos * backImplicit * endAnchor, andFold)


local function anywhere(patt)
	return (1 - patt)^0 * patt
end
local function spaceInFront(patt)
	return other^0 * patt -- Manually insert other^0
end

local simple = (anchor * body / spaceInFront) + (body / anywhere)


local exc = P"!"
local all = P(1)^1 / re.compile
local manual = (exc * exc * all) + (exc * all / anywhere)


return (manual + simple) * -1