local M = {}

-- FileStatus: { [absolute_path: string] = status: string }
-- status values: "modified","added","deleted","renamed","untracked","staged","partial"
M.FileStatus = {}

-- LineChanges: { [absolute_path: string] = { [line_nr: number] = change_type: string } }
-- change_type values: "added","modified","deleted","staged"
-- line_nr is 1-based
M.LineChanges = {}

return M
