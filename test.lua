local sre = require("sre")

local f = string.format



local function test(str, should, shouldnt)
    local parser = assert(sre:match(str), "failed to parse input")
    local wrong = false

	local function throw(case, expected, ...)
		print(f("%q: failed %q: expected %s, got", str, case, expected), ...)
		wrong = true
	end

	for i = 1, #should, 3 do
        local case, exStart, exEnd = should[i], should[i + 1], should[i + 2]

        local acStart, acEnd = parser:match(case)

		if acStart ~= exStart or acEnd ~= exEnd then
			throw(case, exStart .. " " .. exEnd, acStart, acEnd)
		end
	end

    for i = 1, #shouldnt do
        local case = shouldnt[i]

        local acStart, acEnd = parser:match(case)

        if acStart then
            throw(case, "none", acStart, acEnd)
        end
    end

    if not wrong then print("Nothing wrong") end
end

local function testWrong(strs)
	local wrong = false

	for _, str in ipairs(strs) do
		local res = table.pack(sre:match(str))
		if res[1] ~= nil then
			print(f("Invalid %q parsed! Got", str), table.unpack(res, 1, res.n))
			wrong = true
		end
	end

    if not wrong then print("Nothing wrong") end
end

local function testErr(strs)
    local wrong = false

    for _, str in ipairs(strs) do
        local res = table.pack(pcall(sre.match, sre, str))
        if res[1] == true then
            print(f("%q did not error! Got", str), table.unpack(res, 2, res.n))
            wrong = true
        end
    end

    if not wrong then print("Nothing wrong") end
end



-- Basic tests
print("Starting tests")

test("a", {
	"a", 1, 2,
	"a b c", 1, 2,
	"b a c", 3, 4,
	"b c a", 5, 6
}, {
	"ab",
	"ba",
	"bac",
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

-- Esc space
test("hello% there", {
	"hello there", 1, 12,
	"hello there hi", 1, 12,
	"hi hello there", 4, 15,
	"well hello there!", 6, 17,
}, {
	"hello  there", -- two spaces
	"hello	there", -- tab
	"hellothere",
})


-- Dash tests
test("a-b", {
	"acb", 1, 4,
	"aab", 1, 4,
	"akugkfusakb", 1, 12,
	"aakaysfdjb", 1, 11,
}, {
	"ab",
	"abb"
})
test("ab-", {
	"ee abef ee", 4, 8,
	"abef", 1, 5,
}, {
	"ab",
	"feab",
	"feabe",
})
test("-ab", {
	"ee efab ee", 4, 8,
	"feab", 1, 5,
}, {
	"ab",
	"abfe",
	"feabe",
})
test("-ab-", {
	"ee efabe ee", 4, 9,
	"feabe", 1, 6,
}, {
	"ab",
	"ee efab ee",
	"ee abef ee",
	"abfe",
	"feab"
})
test("%-ab", {
	"-ab", 1, 4,
	"e -ab e", 3, 6,
}, {
	"ab",
	"eab",
})
test("a%-b", {
	"a-b", 1, 4,
	"e a-b e", 3, 6,
}, {
	"ab",
	"aeb",
})
test("ab%-", {
	"ab-", 1, 4,
	"e ab- e", 3, 6,
}, {
	"ab",
	"abe",
})

-- Multi tests
test("a/b/c", {
	"a", 1, 2,
	"b", 1, 2,
	"c", 1, 2,
	"f a e", 3, 4,
	"f c e", 3, 4,
}, {
})
test("a-/b", {
	"ae", 1, 3,
	"b", 1, 2
}, {
	"a-"
})
test("a%/b", {
	"a/b", 1, 4,
}, {
	"a",
	"b",
})

-- Amp test
testWrong{"a&b", "a& b", "a &b"}
test("a & b", {
	"a b", 1, 4,
	"a c b", 1, 6,
	"a saf fa d f asf gfa s afaf b", 1, 30,
}, {
	"ab",
	"ae b",
	"a eb",
})
test("a/b & -c", {
	"a bc", 1, 5,
	"a ac", 1, 5,
	"b bc", 1, 5,
	"b ac", 1, 5,
	"a saf fa d f asf gfa s afaf ec", 1, 31,
}, {
	"a c",
	"b c",
})
test("a%& b", {
	"a& b", 1, 5,
}, {
	"a b",
	"a c b",
})
test("a %&b", {
}, {
	"a &b" -- caveat
})

-- Test anchors
testWrong{" |ab", "ba| ", "b|a", " b | a"}
test("|ab", {
	"ab", 1, 3,
	"   ab", 4, 6,
	"ab ce", 1, 3,
}, {
	"ce ab",
})
test("ab|", {
	"ab", 1, 3,
	"ce ab    ", 4, 6,
}, {
	"ab ce",
})
test("|-ab", {
	"   eab", 4, 7,
	"eab ce", 1, 4,
}, {
	"ab",
	"ce ab",
})
test("ab-|", {
	"abe", 1, 4,
	"ce abe    ", 4, 7,
}, {
	"ab",
	"ab ce",
})


-- Test manual
testErr{"!'ab", "!!'ab"}
test("!{}'ab'{} !.", {
	"ab", 1, 3,
	"nice ab", 6, 8,
}, {
	"ab nice",
})
test("!!{}'ab'{} !.", {
	"ab", 1, 3,
}, {
	"ab nice",
	"nice ab",
})



print("Tests done")