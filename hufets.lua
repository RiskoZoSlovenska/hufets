local lpeg = require("lpeg")
local re = require("re")

local WEAK_META = { __mode = "v" }
local mainCached = setmetatable({}, WEAK_META)
local simpleCached = setmetatable({}, WEAK_META)

local P, B = lpeg.P, lpeg.B
local Cp, Cc, Cf = lpeg.Cp, lpeg.Cc, lpeg.Cf



local function lazy(pat, endPat)
	return (pat - endPat)^0 * endPat
end

local function lazyAtLeastOne(pat, endPat)
	return pat * lazy(pat, endPat)
end

local function andFold(a, b) return a * b end
local function orFold(a, b)  return a + b end

local function makeBlindGreedy(p) return p^1 end


local locale = lpeg.locale()

local anchor = P"|"
local literalStart = P"\""
local literalEnd = P"\""
local word = P"_"
local arbitrary = P"..."
local either = P"/"
local manualMark = P"!"

local alnum = locale.alnum
local space = locale.space
local any = P(1)
local none = P(0)
local eof = -any
local nonalnum = any - alnum
local nonmagic = any - (word + either + arbitrary + space + (anchor * eof))

-- Literal stuff
local literal = literalStart * ((any - literalEnd)^0 / P) * literalEnd
local normal = nonmagic^1 / P
local verbatim = literal + normal

-- _s and /s
local anyword = word^1 * Cc(alnum)
local followedAnyword = anyword * verbatim / lazyAtLeastOne
local unfollowedAnyword = anyword / makeBlindGreedy

local choiceGroup = Cf((verbatim + followedAnyword + unfollowedAnyword)^1, andFold)
local choice = either^0 * Cf(choiceGroup * (either * choiceGroup^-1)^0, orFold) + (either^1 * Cc(none))

-- Spaces
local spaces = space^1 * Cc(nonalnum)
local followedSpaces = spaces * choice / lazyAtLeastOne
local unfollowedSpaces = spaces / makeBlindGreedy

local unit = Cf((choice + followedSpaces + unfollowedSpaces)^1, andFold)

-- ...s
local function prependBackNonalnumMatch(p)
	return B(nonalnum) * p
end

local gap = arbitrary * Cc(any)
local doubleSpaceGap = B(space) * arbitrary * (spaces / 0) * Cc(any) * (unit / prependBackNonalnumMatch) / lazy
local followedGap = gap * unit / lazy
local unfollowedGap = gap / makeBlindGreedy

local component = Cf((unit + doubleSpaceGap + followedGap + unfollowedGap)^1, andFold)

-- Everything else
local frontImplicit = Cc(-B(alnum))
local backImplicit  = Cc(-#alnum  )

local endAnchor = ( anchor * eof * Cc(eof) )^-1

local cpos = Cc(Cp())
local body = Cf(frontImplicit * cpos * component^-1 * cpos * backImplicit * endAnchor, andFold)

-- Main 
local function anywhere(patt)
	return (any - patt)^0 * patt
end

local simple = ((anchor * body) + (body / anywhere)) * eof

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
