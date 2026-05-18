local M = {}

M.symbols = {
    modified  = "M",
    added     = "A",
    deleted   = "D",
    renamed   = "R",
    untracked = "?",
    ignored   = "!",
    staged    = "S",
    partial   = "P",
}

M.highlights = {
    modified  = "GitStatusModified",
    added     = "GitStatusAdded",
    deleted   = "GitStatusDeleted",
    renamed   = "GitStatusRenamed",
    untracked = "GitStatusUntracked",
    ignored   = "GitStatusIgnored",
    staged    = "GitStatusStaged",
    partial   = "GitStatusPartial",
}

M.debounce_ms   = 300
M.sign_priority = 10

return M
