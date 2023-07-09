local lpeg = require("lpeg")
local re = require("re")

local WEAK_META = { __mode = "v" }
local mainCached = setmetatable({}, WEAK_META)
local simpleCached = setmetatable({}, WEAK_META)

local P, S, B = lpeg.P, lpeg.S, lpeg.B
local Cp, Cc, Cf = lpeg.Cp, lpeg.Cc, lpeg.Cf



local function repeatPat(pat, n) -- Base borrowed from LPeg's re.lua
	local out = P(true)
	while n >= 1 do
		if n % 2 >= 1 then
			out = out * pat
		end
		pat = pat * pat
		n = n / 2
	end
	return out
end

local function lazy(pat, endPat)
	return (pat - endPat)^0 * endPat
end

local function lazyAtLeastN(n, pat, endPat)
	return repeatPat(pat, n) * lazy(pat, endPat)
end

local function andFold(a, b) return a * b end
local function orFold(a, b)  return a + b end

local function makeBlindGreedy(p) return p^1 end
local function lenCapture(str) return #str end


local locale = lpeg.locale()

local anchor = P"|"
local literalStart = P"\""
local literalEnd = P"\""
local quote = P"'"
local word = P"_"
local arbitrary = P"..."
local either = P"/"
local manualMark = P"!"

local alnum = locale.alnum
local space = locale.space
local any = P(1)
local none = P(0)
local eof = space^0 * -any
local nonalnum = any - alnum
local nonmagic = any - (word + either + arbitrary + space + (anchor * eof))

-- Literal stuff
local single = quote * Cc(S"\"'")
local function matchSingleOrPatt(patt) return single + (patt - single)^1 / P end

local literal = literalStart * Cf(Cc(true) * matchSingleOrPatt(any - literalEnd)^0, andFold) * literalEnd
local text = Cf(matchSingleOrPatt(nonmagic)^1, andFold)
local verbatim = literal + text

-- _s and /s
local anyword = (word^1 / lenCapture) * Cc(alnum)
local followedAnyword = anyword * verbatim / lazyAtLeastN
local unfollowedAnyword = anyword / 2 / makeBlindGreedy

local choiceGroup = Cf((verbatim + followedAnyword + unfollowedAnyword)^1, andFold)
local choice = either^0 * Cf(choiceGroup * (either^1 * choiceGroup)^0, orFold) + (either^1 * Cc(none))

-- Spaces
local spaces = space^1 * Cc(1) * Cc(nonalnum)
local followedSpaces = spaces * choice / lazyAtLeastN
-- local unfollowedSpaces = (spaces - eof - (space^0 * anchor * eof)) / 2 / makeBlindGreedy

local unit = Cf((choice + followedSpaces --[[+ unfollowedSpaces]])^1, andFold)

-- ...s
local function prependBackNonalnumMatch(p)
	return B(nonalnum) * p
end

local gap = arbitrary * Cc(any)
local doubleSpaceGap = B(space) * gap * (spaces / 0) * (unit / prependBackNonalnumMatch) / lazy
local followedGap = gap * unit / lazy
local unfollowedGap = gap / makeBlindGreedy
local gapWithPreSpaces = (spaces / 2) * (doubleSpaceGap + followedGap + unfollowedGap) / andFold

local component = Cf((unit + gapWithPreSpaces + doubleSpaceGap + followedGap + unfollowedGap)^1, andFold)

-- Everything else
local frontImplicit = Cc(space^0 * -B(alnum))
local backImplicit  = Cc(-#alnum * space^0  )

local endAnchor = spaces^0 * anchor * eof * Cc(eof)

local cpos = Cc(Cp())
local body = Cf(frontImplicit * cpos * component^-1 * cpos * backImplicit * endAnchor^-1, andFold)

-- Main 
local function anywhere(patt)
	return (any - patt)^0 * patt
end

local simple = space^0 * ((anchor * space^0 * body) + (body / anywhere)) * eof

-- Manual (!s)
local all = any^1 / re.compile
local allNoCaptures = all / function(p) return p / 0 end
local fullyManual = manualMark * manualMark * all
local assistedManual = manualMark * Cf(frontImplicit * cpos * allNoCaptures * cpos * backImplicit, andFold) / anywhere
local manual = (fullyManual + assistedManual) * eof

local main = manual + simple



-- Library utility functions
local function compile(pattern, allowManual)
	local cache = allowManual and mainCached or simpleCached

	if not cache[pattern] then
		local object = allowManual and main or simple
		local ok, res = pcall(object.match, object, pattern)
		if not ok then
			return nil, "malformed pattern: " .. res
		elseif not res then
			return nil, "malformed pattern"
		end

		cache[pattern] = res
	end

	return cache[pattern]
end

local function match(str, pattern, start, allowManual)
	local matcher, err = compile(pattern, allowManual)
	if not matcher then
		return nil, nil, err
	end

	local ok, startPos, endPos = pcall(matcher.match, matcher, str, start)
	if not ok then
		return nil, nil, "match failed: " .. startPos

	elseif startPos == nil and endPos == nil then
		return nil, nil, nil

	elseif type(startPos) ~= "number" and type(endPos) ~= "number" then
		return nil, nil, "match returned invalid values"
	end

	return startPos, endPos
end


return {
	compile = compile,
	match = match,
}
