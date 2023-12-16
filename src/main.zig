// taken from exercism
// https://github.com/exercism/zig/blob/main/exercises/practice/word-count/test_word_count.zig
const std = @import("std");
const mem = std.mem;
const testing = std.testing;

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var counts = try countWordsAlloc(alloc, "The quick brown fox jumped over the lazy dog.");
    defer freeKeysAndDeinit(&counts);
    std.debug.print("{}\n", .{counts});
}

pub fn toLowercaseAlloc(alloc: std.mem.Allocator, inp: []const u8) ![]const u8 {
    var out = try alloc.alloc(u8, inp.len);
    var index: usize = 0;
    for (inp) |c| {
        out[index] = std.ascii.toLower(c);
        index += 1;
    }
    return out;
}

fn sliceContains(slice: []const u8, value: u8) bool {
    for (slice) |item| {
        if (item == value) {
            return true;
        }
    }
    return false;
}

const WordBoundaries = struct {
    const Self = @This();
    ifirst: usize, // first letter of the word
    ilast: usize, // last letter of the word
    inext: usize, // first character that is possibly part of the next word

    pub fn isValid(self: WordBoundaries) bool {
        return self.ifirst <= self.ilast;
    }

    pub fn createInvalid() WordBoundaries {
        return WordBoundaries{
            .ifirst = 2,
            .ilast = 1,
            .inext = 0,
        };
    }

    pub fn getSlice(self: Self, inp: []const u8) []const u8 {
        return inp[self.ifirst .. self.ilast + 1];
    }

    pub fn getWordLowerAlloc(self: Self, alloc: std.mem.Allocator, inp: []const u8) ![]const u8 {
        const w = self.getSlice(inp);
        return toLowercaseAlloc(alloc, w);
    }

    pub fn findNext(inp: []const u8, istart: usize) WordBoundaries {
        const apostrophe: u8 = '\'';
        const separators = " \t\n.:,;!?&^$%@(){}[]<>";
        _ = separators;
        var ifirst = istart;
        while (true) {
            if (ifirst >= inp.len) {
                break;
            }
            const c: u8 = inp[ifirst];
            if (c == apostrophe) {
                ifirst += 1;
            } else if (std.ascii.isAlphanumeric(c)) {
                break;
            } else {
                ifirst += 1;
            }
        }
        if (ifirst >= inp.len) {
            return WordBoundaries.createInvalid();
        }
        var ilast = ifirst; // last non apostrophe
        var inext = ilast + 1;
        while (true) {
            if (inext >= inp.len) {
                break;
            }
            const c = inp[inext];
            if (c == apostrophe) {
                inext += 1;
            } else if (std.ascii.isAlphanumeric(c)) {
                ilast = inext;
                inext += 1;
            } else {
                inext += 1;
                break;
            }
        }
        return WordBoundaries{ .ifirst = ifirst, .ilast = ilast, .inext = inext };
    }
};

test "WordBoundaries" {
    const s = "one fish  two!?fish 'RED' fish'' blue fi'sh...123";
    var b = WordBoundaries.findNext(s, 0);
    try testing.expect(b.isValid());
    try testing.expectEqualSlices(u8, b.getSlice(s), "one");

    b = WordBoundaries.findNext(s, b.inext);
    try testing.expect(b.isValid());
    try testing.expectEqualSlices(u8, b.getSlice(s), "fish");

    b = WordBoundaries.findNext(s, b.inext);
    try testing.expect(b.isValid());
    try testing.expectEqualSlices(u8, b.getSlice(s), "two");

    b = WordBoundaries.findNext(s, b.inext);
    try testing.expect(b.isValid());
    try testing.expectEqualSlices(u8, b.getSlice(s), "fish");

    b = WordBoundaries.findNext(s, b.inext);
    try testing.expect(b.isValid());
    try testing.expectEqualSlices(u8, b.getSlice(s), "RED");

    b = WordBoundaries.findNext(s, b.inext);
    try testing.expect(b.isValid());
    try testing.expectEqualSlices(u8, b.getSlice(s), "fish");

    b = WordBoundaries.findNext(s, b.inext);
    try testing.expect(b.isValid());
    try testing.expectEqualSlices(u8, b.getSlice(s), "blue");

    b = WordBoundaries.findNext(s, b.inext);
    try testing.expect(b.isValid());
    try testing.expectEqualSlices(u8, b.getSlice(s), "fi'sh");

    b = WordBoundaries.findNext(s, b.inext);
    try testing.expect(b.isValid());
    try testing.expectEqualSlices(u8, b.getSlice(s), "123");

    b = WordBoundaries.findNext(s, b.inext);
    try testing.expect(!b.isValid());
}

/// Returns the counts of the words in `s`.
/// Caller owns the returned memory.
pub fn countWordsAlloc(alloc: mem.Allocator, s: []const u8) !std.StringHashMap(u32) {
    var out = std.StringHashMap(u32).init(alloc);
    var b = WordBoundaries.findNext(s, 0);
    while (b.isValid()) {
        const word = try b.getWordLowerAlloc(alloc, s);
        std.debug.assert(word.len > 0);
        var entry = try out.getOrPut(word);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
            alloc.free(word);
        } else {
            entry.value_ptr.* = 1;
        }
        b = WordBoundaries.findNext(s, b.inext);
    }
    return out;
}

fn freeKeysAndDeinit(self: *std.StringHashMap(u32)) void {
    var iter = self.keyIterator();
    while (iter.next()) |key_ptr| {
        self.allocator.free(key_ptr.*);
    }
    self.deinit();
}

test "count one word" {
    const s = "word";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 1), map.count());
    try testing.expectEqual(@as(?u32, 1), map.get("word"));
}

test "count one of each word" {
    const s = "one of each";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 3), map.count());
    try testing.expectEqual(@as(?u32, 1), map.get("one"));
    try testing.expectEqual(@as(?u32, 1), map.get("of"));
    try testing.expectEqual(@as(?u32, 1), map.get("each"));
}

test "multiple occurrences of a word" {
    const s = "one fish two fish red fish blue fish";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 5), map.count());
    try testing.expectEqual(@as(?u32, 1), map.get("one"));
    try testing.expectEqual(@as(?u32, 4), map.get("fish"));
    try testing.expectEqual(@as(?u32, 1), map.get("two"));
    try testing.expectEqual(@as(?u32, 1), map.get("red"));
    try testing.expectEqual(@as(?u32, 1), map.get("blue"));
}

test "handles cramped lists" {
    const s = "one,two,three";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 3), map.count());
    try testing.expectEqual(@as(?u32, 1), map.get("one"));
    try testing.expectEqual(@as(?u32, 1), map.get("two"));
    try testing.expectEqual(@as(?u32, 1), map.get("three"));
}

test "handles expanded lists" {
    const s = "one,\ntwo,\nthree";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 3), map.count());
    try testing.expectEqual(@as(?u32, 1), map.get("one"));
    try testing.expectEqual(@as(?u32, 1), map.get("two"));
    try testing.expectEqual(@as(?u32, 1), map.get("three"));
}

test "ignore punctuation" {
    const s = "car: carpet as java: javascript!!&@$%^&";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 5), map.count());
    try testing.expectEqual(@as(?u32, 1), map.get("car"));
    try testing.expectEqual(@as(?u32, 1), map.get("carpet"));
    try testing.expectEqual(@as(?u32, 1), map.get("as"));
    try testing.expectEqual(@as(?u32, 1), map.get("java"));
    try testing.expectEqual(@as(?u32, 1), map.get("javascript"));
}

test "include numbers" {
    const s = "testing, 1, 2 testing";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 3), map.count());
    try testing.expectEqual(@as(?u32, 2), map.get("testing"));
    try testing.expectEqual(@as(?u32, 1), map.get("1"));
    try testing.expectEqual(@as(?u32, 1), map.get("2"));
}

test "normalize case" {
    const s = "go Go GO Stop stop";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 2), map.count());
    try testing.expectEqual(@as(?u32, 3), map.get("go"));
    try testing.expectEqual(@as(?u32, 2), map.get("stop"));
}

test "with apostrophes" {
    const s = "'First: don't laugh. Then: don't cry. You're getting it.'";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 8), map.count());
    try testing.expectEqual(@as(?u32, 1), map.get("first"));
    try testing.expectEqual(@as(?u32, 2), map.get("don't"));
    try testing.expectEqual(@as(?u32, 1), map.get("laugh"));
    try testing.expectEqual(@as(?u32, 1), map.get("then"));
    try testing.expectEqual(@as(?u32, 1), map.get("cry"));
    try testing.expectEqual(@as(?u32, 1), map.get("you're"));
    try testing.expectEqual(@as(?u32, 1), map.get("getting"));
    try testing.expectEqual(@as(?u32, 1), map.get("it"));
}

test "with quotations" {
    const s = "Joe can't tell between 'large' and large.";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 6), map.count());
    try testing.expectEqual(@as(?u32, 1), map.get("joe"));
    try testing.expectEqual(@as(?u32, 1), map.get("can't"));
    try testing.expectEqual(@as(?u32, 1), map.get("tell"));
    try testing.expectEqual(@as(?u32, 1), map.get("between"));
    try testing.expectEqual(@as(?u32, 2), map.get("large"));
    try testing.expectEqual(@as(?u32, 1), map.get("and"));
}

test "substrings from the beginning" {
    const s = "Joe can't tell between app, apple and a.";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 8), map.count());
    try testing.expectEqual(@as(?u32, 1), map.get("joe"));
    try testing.expectEqual(@as(?u32, 1), map.get("can't"));
    try testing.expectEqual(@as(?u32, 1), map.get("tell"));
    try testing.expectEqual(@as(?u32, 1), map.get("between"));
    try testing.expectEqual(@as(?u32, 1), map.get("app"));
    try testing.expectEqual(@as(?u32, 1), map.get("apple"));
    try testing.expectEqual(@as(?u32, 1), map.get("and"));
    try testing.expectEqual(@as(?u32, 1), map.get("a"));
}

test "multiple spaces not detected as a word" {
    const s = " multiple   whitespaces";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 2), map.count());
    try testing.expectEqual(@as(?u32, 1), map.get("multiple"));
    try testing.expectEqual(@as(?u32, 1), map.get("whitespaces"));
}

test "alternating word separators not detected as a word" {
    const s = ",\n,one,\n ,two \n 'three'";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 3), map.count());
    try testing.expectEqual(@as(?u32, 1), map.get("one"));
    try testing.expectEqual(@as(?u32, 1), map.get("two"));
    try testing.expectEqual(@as(?u32, 1), map.get("three"));
}

test "quotation for word with apostrophe" {
    const s = "can, can't, 'can't'";
    var map = try countWordsAlloc(testing.allocator, s);
    defer freeKeysAndDeinit(&map);
    try testing.expectEqual(@as(u32, 2), map.count());
    try testing.expectEqual(@as(?u32, 1), map.get("can"));
    try testing.expectEqual(@as(?u32, 2), map.get("can't"));
}
