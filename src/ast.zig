const Selector = union(enum) {
    Match: Matcher,
    All: ExploreAll,
    Fields: ExploreFields,
    Index: ExploreIndex,
    Range: ExploreRange,
    Recursive: ExploreRecursive,
    Union: ExploreUnion,
    Conditional: ExploreConditional,
    Recurse: void,

    pub fn match() Selector {
        return Selector{
            .Match = Matcher{ .onlyIf = null, .label = null },
        };
    }

    pub fn matchLabelled(label: []u8) Selector {
        return Selector{
            .Match = Matcher{ .onlyIf = null, .label = label },
        };
    }

    pub fn all(next: *const Selector) Selector {
        return Selector{
            .All = ExploreAll{ .next = next },
        };
    }

    pub fn recurse() Selector {
        return Selector{ .Recurse = undefined };
    }

    pub fn fielded(fields: []const FieldEntry) Selector {
        return Selector{
            .Fields = ExploreFields{ .fields = fields },
        };
    }

    pub fn indexed(index: u32, next: *const Selector) Selector {
        return Selector{
            .Index = ExploreIndex{ .index = index, .next = next },
        };
    }

    pub fn range(start: u32, end: u32, next: *const Selector) Selector {
        return Selector{
            .Range = ExploreRange{ .start = start, .end = end, .next = next },
        };
    }

    pub fn recursive(sequence: *const Selector) Selector {
        return Selector{
            .Recursive = ExploreRecursive{
                .limit = RecursionLimit.None,
                .sequence = sequence,
                .stopAt = null,
            },
        };
    }
    pub fn recursiveLimited(limit: u32, sequence: *const Selector) Selector {
        return Selector{
            .Recursive = ExploreRecursive{
                .limit = RecursionLimit{ .Depth = limit },
                .sequence = sequence,
                .stopAt = undefined,
            },
        };
    }

    pub fn unioned(list: []*const Selector) Selector {
        return Selector{
            .Union = ExploreUnion{ .list = list },
        };
    }

    pub fn conditional(condition: Condition, next: *const Selector) Selector {
        return Selector{
            .Conditional = ExploreConditional{ .condition = condition, .next = next },
        };
    }
};

const Matcher = struct {
    onlyIf: ?Condition = null,
    label: ?[]u8 = null,
};

const ExploreAll = struct {
    next: *const Selector,
};

const FieldEntry = struct {
    field: []const u8,
    next: *const Selector,

    pub fn init(field: []const u8, next: *const Selector) FieldEntry {
        return FieldEntry{ .field = field, .next = next };
    }
};

const ExploreFields = struct {
    fields: []const FieldEntry,
};

const ExploreIndex = struct {
    index: u32,
    next: *const Selector,
};

const ExploreRange = struct {
    start: u32,
    end: u32,
    next: *const Selector,
};

const ExploreRecursive = struct {
    limit: RecursionLimit,
    sequence: *const Selector,
    stopAt: ?Condition = null,
};

const ExploreUnion = struct {
    list: []*const Selector,
};

const ExploreConditional = struct {
    condition: Condition,
    next: *const Selector,
};

const Condition = struct {}; // TODO: specify this.
const RecursionLimit = union(enum) {
    None: void,
    Depth: u32,
};
