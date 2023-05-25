local hufets = require("hufets")
local f = string.format

local wrongs = 0


local function test(str, should, shouldnt)
    local wrong = false

	local function throw(case, expected, ...)
		print(f("%q: failed %q: expected %s, got", str, case, expected), ...)
		wrong = true
		wrongs = wrongs + 1
	end

	for i = 1, #should, 3 do
        local case, exStart, exEnd = should[i], should[i + 1], should[i + 2]

        local acStart, acEnd, err = hufets.match(case, str, 1, true)

		if acStart ~= exStart or acEnd ~= exEnd then
			throw(case, exStart .. " " .. exEnd, acStart, acEnd, err)
		end
	end

    for i = 1, #shouldnt do
        local case = shouldnt[i]

        local acStart, acEnd = hufets.match(case, str, 1, true)

        if acStart then
            throw(case, "none", acStart, acEnd)
        end
    end

    if not wrong then print("Nothing wrong") end
end

local function testErr(strs)
    local wrong = false

    for _, str in ipairs(strs) do
		local matcher = hufets.compile(str, true)
        if matcher then
            print(f("%q did not error! Got %s", str, matcher))
            wrong = true
        end
    end

    if not wrong then print("Nothing wrong") end
end



-- Basic tests
print("Starting tests")

test("a", {
	"a", 1, 2,
	'"a"', 2, 3,
	"a b c", 1, 2,
	"b a c", 3, 4,
	"b c a", 5, 6,
}, {
	"ab",
	"ba",
	"bac",
})
test("a..", {
	"a..", 1, 4,
}, {
	"a",
})
test(" a ", {
	" a ", 1, 4,
	" !a? ", 1, 6,
}, {
	"a",
	"a ",
	" a",
})
test("hello there", {
	"hello there", 1, 12,
	"hello!there", 1, 12,
	"hello       there", 1, 18,
	"well hello there!", 6, 17,
	"hello there hi", 1, 12,
	"hi hello there", 4, 15,
}, {
	"hello",
	"there",
	"hellothere",
	"ehello there",
	"hello theree",
	"hello no there",
})
test("a !b", {
	"a    !b", 1, 8,
	"a !  !b", 1, 8,
}, {
	"a!b",
	"a ! b",
	"a  b",
})


-- Word tests
test("a_b", {
	"acb", 1, 4,
	"aab", 1, 4,
	"abb", 1, 4,
	"akugkfusakb", 1, 12,
	"aakaysfdjb", 1, 11,
}, {
	"ab",
	"abbb", -- Caveat
})
test("a__b", {
	"acb", 1, 4,
}, {
	"abbb",
})
test("ab_", {
	"ee abef ee", 4, 8,
	"abef", 1, 5,
}, {
	"ab",
	"feab",
	"feabe",
})
test("_ab", {
	"ee efab ee", 4, 8,
	"feab", 1, 5,
}, {
	"ab",
	"abfe",
	"feabe",
})
test("_ab_", {
	"ee efabe ee", 4, 9,
	"feabe", 1, 6,
}, {
	"ab",
	"ee efab ee",
	"ee abef ee",
	"abfe",
	"feab"
})
test("a_bc_d_", {
	"abbccdd", 1, 8,
	"abbbcbdd", 1, 9,
}, {
	"abbbbdd",
})

-- Multi tests
test("a/b/c", {
	"a", 1, 2,
	"b", 1, 2,
	"c", 1, 2,
	"f a e", 3, 4,
	"f c e", 3, 4,
}, {
	"f",
	"ab",
})
test("a_/b", {
	"ae", 1, 3,
	"b", 1, 2
}, {
	"a-"
})
test("a///b", {
	"a", 1, 2,
	"b", 1, 2,
}, {
	"c",
	""
})
test("//a///b/c/", {
	"a", 1, 2,
	"b", 1, 2,
	"c", 1, 2,
}, {
	"",
	"/",
})
test("a/", {
	"a", 1, 2,
}, {
	"b"
})
test("/a", {
	"a", 1, 2,
}, {
	"b"
})
test("/", {
	"", 1, 1,
}, {})
test("//", {
	"", 1, 1,
}, {})

-- Literal tests
test('"hello there"', {
	"hello there", 1, 12,
	"aaa hello there bbb", 5, 16,
	'"hello there"', 2, 13,
}, {
	"hello  there",
	"ahello there",
	"hello theres",
})
test('_" "', {
	"b ", 1, 3,
}, {
	"bb",
	" b",
})
test('"a"_"b"', {
	"acb", 1, 4,
	"aab", 1, 4,
	"abb", 1, 4,
	"akugkfusakb", 1, 12,
	"aakaysfdjb", 1, 11,
}, {
	"ab",
})
test('"a"/b', {
	"a", 1, 2,
	"b", 1, 2,
}, {
	"c",
})
test('"""', {
	'"', 1, 2
}, {
	"",
})
test('""', {
	"", 1, 1
}, {
	"a",
})


-- Gap test
test("a...a", {
	"aa", 1, 3,
	"aba", 1, 4,
	"a    a", 1, 7,
	"a  b  a", 1, 8,
}, {
	"ab",
	"ae b",
	"a eb",
	"aaa", -- Caveat
})
test("a... b", {
	"a b", 1, 4,
	"ac b", 1, 5,
	"a   b", 1, 6,
	"ac   b", 1, 7,
}, {
	"ab",
	"acb",
})
test("a ...b", {
	"a b", 1, 4,
	"a cb", 1, 5,
	"a   b", 1, 6,
	"a   cb", 1, 7,
}, {
	"ab",
	"acb",
})
test("a...b", {
	"ab", 1, 3,
	"aab", 1, 4,
}, {
	"abb",
})
test("a ... b", {
	"a b", 1, 4,
	"a c b", 1, 6,
	"a saf fa d f asf gfa s afaf b", 1, 30,
}, {
	"ab",
	"ae b",
	"a eb",
})
test("a/b ... _c", {
	"a bc", 1, 5,
	"a ac", 1, 5,
	"b bc", 1, 5,
	"b eac", 1, 6,
	"a saf fa d f asf gfa s afaf ec", 1, 31,
}, {
	"a c",
	"b c",
	"ae bc",
})

test("a ... b ... c", {
	"a b c", 1, 6,
	"  a  e  b   f   c	", 3, 18,
	"a b c c", 1, 6,
}, {
	"a c",
	"b c",
	"ab c",
	"abc",
})

-- Test anchors
test("|ab", {
	"ab", 1, 3,
	"ab ce", 1, 3,
}, {
	" ab",
	"ce ab",
})
test("ab|", {
	"c ab", 3, 5,
}, {
	"ab ce",
	"ce ab ",
})
test("a |", {
	"a ", 1, 3,
}, {
	"a",
	"",
})
test("| a", {
	" a", 1, 3,
}, {
	"a",
	"",
})
test("|_ab", {
	"eab ce", 1, 4,
}, {
	"ab",
	" eab",
	"ce ab",
})
test("ab_|", {
	"abe", 1, 4,
	"c abe", 3, 6,
}, {
	"ab",
	"abe ",
	"ab ce",
})
test(" |a", {
	"  |a", 1, 5,
}, {
	"a",
})
test("a| ", {
	"a|  ", 1, 5,
}, {
	"a",
})
test("a|b", {
	"a|b", 1, 4,
	"e  a|b   c", 4, 7,
}, {
	"a",
})
test("|", {
	"", 1, 1,
	" ", 1, 1,
	" a", 1, 1,
}, {
	"a",
	"a ",
})
test(" |", {
	" ", 1, 2,
	"a  ", 3, 4,
}, {
	"a",
	"  a",
	"a ",
})
test("| ", {
	" ", 1, 2,
}, {
	"a",
})
test(" | ", {
	" | ", 1, 4,
}, {
	" ",
	"   ",
})


-- Test manual
testErr{"!'ab", "!!'ab"}
test("!'ab' !.", {
	"ab", 1, 3,
	"nice ab", 6, 8,
}, {
	"ab nice",
	"cab",
})
test("!'a'{}'b' !.", { -- Test capture discarding
	"ab", 1, 3,
}, {})
test("!!{}'ab'{} !.", {
	"ab", 1, 3,
}, {
	"ab nice",
	"nice ab",
	" ab",
})

-- Empty input string
test("", {
	"", 1, 1,
	" ", 1, 1,
	"a ", 3, 3,
}, {
	"a",
})


print(f("Tests done: %d failures", wrongs))
if wrongs > 0 then
	error("Tests failed", 0)
end
