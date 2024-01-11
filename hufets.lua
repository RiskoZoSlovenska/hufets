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

local function lazyAtLeastOne(pat, endPat)
	return lazyAtLeastN(1, pat, endPat)
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
local dash = "-"
local arbitrary = P"."^3
local either = P"/"
local manualMark = P"!"

local alnum = locale.alnum
local space = locale.space
local optspace = space^0
local always = P(true)
local any = P(1)
local eof = optspace * -any
local nonalnum = any - alnum
local nonmagic = any - (word + either + arbitrary + (optspace * (anchor + dash) * eof) + space)

local noAlnumBefore = -B(alnum)
local noAlnumAfter  = -#alnum  

-- Literal stuff
local single = quote * Cc(S"\"'")
local function matchSingleOrPatt(patt)
	return single + (patt - single)^1 / P
end

local literal = literalStart * Cf(Cc(always) * matchSingleOrPatt(any - literalEnd)^0, andFold) * literalEnd
local text = Cf(matchSingleOrPatt(nonmagic - literal)^1, andFold)
local verbatim = literal + text

-- _s and /s
local anyword = (word^1 / lenCapture) * Cc(alnum)
local followedAnyword = anyword * verbatim / lazyAtLeastN
local unfollowedAnyword = anyword / 2 / makeBlindGreedy

local choiceGroup = Cf((verbatim + followedAnyword + unfollowedAnyword)^1, andFold)
local justEither = either^1 * optspace * Cc(always)
local choice = either^0 * Cf(choiceGroup * (either^1 * choiceGroup)^0, orFold) * either^0 + justEither

-- Spaces
local spaces = space^1 * Cc(nonalnum)
local followedSpaces = spaces * choice / lazyAtLeastOne
local unit = Cf((choice + followedSpaces)^1, andFold)

-- ...s
local gapPreSpace  = space^1 * Cc(noAlnumAfter)  + Cc(always)
local gapPostSpace = space^1 * Cc(noAlnumBefore) + Cc(always)
local gap = gapPreSpace * arbitrary * (space^1 * arbitrary)^0 * gapPostSpace

local function makeGap(pre, post, func, target)
	return pre * func(any, target and (post * target) or nil)
end

local followedGap   = gap * Cc(lazyAtLeastOne)  * unit / makeGap
local unfollowedGap = gap * Cc(makeBlindGreedy)        / makeGap
local component = Cf((followedGap + unfollowedGap + unit)^1, andFold)

-- Anchors
local anchorFront = anchor * optspace * Cc(nonalnum) * Cc(noAlnumBefore)
local dashFront = dash * -#space * Cc(any) * Cc(P(true))
local noFront = Cc(any) * Cc(noAlnumBefore)
local front = anchorFront + dashFront + noFront

local anchorBack = optspace * anchor * eof * Cc(noAlnumAfter * nonalnum^0 * eof)
local dashBack = -B(space) * dash * eof * Cc(P(true))
local noBack = Cc(noAlnumAfter)
local back = anchorBack + dashBack + noBack

local cpos = Cc(Cp())

local bodyWithoutFront = Cf(cpos * component^-1 * cpos * back, andFold)
local simple = optspace * (front * bodyWithoutFront / function(preBody, boundary, body)
	return lazy(preBody, boundary * body)
end) * eof


-- Manual (!s)
local all = any^1 / re.compile
local allNoCaptures = all / function(p) return p / 0 end
local fullyManual = manualMark * manualMark * all
local assistedManual = manualMark * Cc(any) * Cf(Cc(noAlnumBefore) * cpos * allNoCaptures * cpos * Cc(noAlnumAfter), andFold) / lazy
local manual = optspace * (fullyManual + assistedManual) * eof

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
