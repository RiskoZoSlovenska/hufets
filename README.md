# HUFETS: **HU**man-**F**riendly **E**xpressions for **T**ext **S**earching

HUFETS is a minimalistic "regex" for searching within written text. It's meant to be forgiving to write and readable even by non-programmers.

The basic gist is:

* Letters, digits and most punctuation match themselves
* Things inside quotes are matched literally
* Whitespace matches non-alphanumeric characters
* `_` matches alphanumeric characters
* `/` matches options
* `...` matches any characters


## Installation

HUFETS is still unstable and the syntax may be subject to change. While I plan on publishing it to [LuaRocks](https://luarocks.org/) when it's stable, for now, install it by building manually:
```
git clone https://github.com/RiskoZoSlovenska/hufets
cd hufets
luarocks make
```


## Syntax

Note that this specification is still a work in progress, and some smaller details, such as handling of edge cases, may change.

### General

As mentioned, alphanumerics and most punctuation match themselves. Additionally, the matched string must be flanked by non-alphanumerics on both sides (i.e. `a` matches `a` and `b a c` but not `ab` or `bac`).

### Quotes

Any characters between an opening quote (`"`) and a closing quote (also a `"`) are matched literally (without the quotes themselves). Quotes cannot be put into quotes (since they act as closing quotes), meaning that there is no way to escape them. When there is an unbalanced amount of quotes in the pattern, the last quote is matched literally.

### Spaces

Any sequences of whitespace characters in the pattern matches any sequence of non-alphanumeric characters. At least one character must be matched and the rest of the characters are matched lazily, so that the pattern `a !b` matches `a !b` and `a ! !b`, but not `a ! b`, `a!b` or `a  b`. Flanking spaces in the pattern signify that the string must also be flanked by whitespace.

### Underscores

Any sequences of underscores (`_`s) in the pattern matches any sequence of alphanumeric characters. At least one character must be matched and the rest of the characters are matched lazily, so that the pattern `a_b` matches `aab` and `acdb`, but not `ab`. **Note:** Because the pattern uses a lazy match, `a_b` (nor `a__b`, which is the same thing) will *not* match something like `abbb`.

### Slashes

Multiple sequences of alphanumerics and underscores separated by one or more slashes (`/`s) match one of the sequences (i.e. `a/b_` will try to match both `a` and `b_`). Any leading, trailing, or duplicate slashes are ignored: `//a///b/` is equal to `a/b`, and `///` (or any number of repeated slashes) is equal to `""` (a literal match for the empty string).

### Ellipses

An ellipse (a sequence of three periods, `...`, *not* the [Unicode character](https://www.compart.com/en/unicode/U+2026)) matches any sequence of characters. The match is done lazily, but unlike other lazy matches, does not have to match a character at all. For example, `a...b` matches `ab`, `aab` and `ac e fb`, but (because the match is lazy), does not match `abb`.

As a special case, if the ellipse is both preceded and followed by whitespace, the whitespace that follows it can overlap with the preceding space. This ensures that `a ... b` matches `a b` (but not `a cb` or `ac b`).

### Anchors

Anchoring is done using the pipe character (`|`) at the beginning or the end of the pattern. For example, `|a` matches `a b` but not `b a`. When found anywhere else in the pattern, the pipe is interpreted literally. Edge cases in which the pattern consists of only the pipe, or only the pipe and whitespace may result in the pattern matching empty strings/whitespace sequences (albeit ones that still have to follow the implicit no-alphanumerics-on-sides rule) at the beginning or end of the string. For example, ` |` will match and `a  `, but not the empty string or `a` (whitespace must be matched), `  a` (whitespace must be at the end), or `a ` (matched whitespace must not be flanked by alphanumerics).

### Manual

If the pattern begins with an exclamation mark (`!`), the rest of the pattern is passed to lpeg's `re.compile` function and the resulting object is used as the body of the pattern. Positional captures are inserted on either side, the pattern becomes subject to the usual no-flanking-alphanumerics rule, is allowed to match anywhere in a string, and has any other captures discarded.

If the pattern begins with two exclamation marks, the rest of the pattern is passed to lpeg's `re.compile` and the resulting object is used as the matcher, without any extra bells or whistles appended to it. The pattern is expected to contain two positional captures (the start and the end); including any other captures will cause undefined behaviour.

Exclamation marks anywhere else in the pattern are interpreted literally.


## Docs

The library returns two functions:

### compile(pattern, allowManual)

Parses `pattern` (a string) as a HUFETS pattern and returns the resulting lpeg object. If parsing fails, the first return value will be nil and the second will be an error string. The value of the `allowManual` flag (a boolean) determines whether HUFETS will parse [manual patterns](#manual). Compile patterns are stored in a weak table and successive calls with the same arguments may yield the same object.

### match(str, pattern, start, allowManual)

This function is mostly equal to `compile(pattern, allowManual):match(str, start)`, except that it also handles errors and validates that the return values are numbers. If the pattern fails to parse or throws an error while matching (should only happen when using [manual patterns](#manual)) the function will return two `nil`s followed by a string error message. If the pattern fails to match, three `nil`s will be returned.


## Development

Run tests:
```
lua test.lua
```
