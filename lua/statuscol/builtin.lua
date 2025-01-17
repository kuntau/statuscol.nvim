local c = vim.cmd
local d = vim.diagnostic
local l = vim.lsp
local npc = vim.F.npcall
local O = vim.opt
local v = vim.v
local foldmarker
local fillchars = O.fillchars:get()
local foldopen = fillchars.foldopen or "-"
local foldclosed = fillchars.foldclose or "+"
local foldsep = fillchars.foldsep or "│"
local M = {}

--- Return line number in configured format.
function M.lnumfunc(number, relativenumber, thousands, relculright)
	if v.virtnum ~= 0 or (not relativenumber and not number) then return "" end
	local lnum = v.lnum

	if relativenumber then
		lnum = v.relnum > 0 and v.relnum or (number and lnum or 0)
	end

	if thousands and lnum > 999 then
		lnum = string.reverse(lnum):gsub("%d%d%d", "%1"..thousands):reverse():gsub("^%"..thousands, "")
	end

	if not relculright and relativenumber then
		lnum = (v.relnum > 0 and "%=" or "")..lnum..(v.relnum > 0 and "" or "%=")
	else
		lnum = "%="..lnum
	end

	return lnum
end

--- Return fold column in configured format.
function M.foldfunc(foldinfo, width)
	if width == 0 then return "" end

	local string = v.relnum > 0 and "%#FoldColumn#" or "%#CursorLineFold#"
	local level = foldinfo.level

	if level == 0 then
		return string..(" "):rep(width).."%*"
	end

	local closed = foldinfo.lines > 0
	local first_level = level - width - (closed and 1 or 0) + 1
	if first_level < 1 then first_level = 1 end

	-- For each column, add a foldopen, foldclosed, foldsep or whitespace char
	for col = 1, width do
		if closed and (col == level or col == width) then
			string = string..foldclosed
		elseif foldinfo.start == v.lnum and first_level + col > foldinfo.llevel then
			string = string..foldopen
		else
			string = string..foldsep
		end

		if col == level then
			string = string..(" "):rep(width - col)
			break
		end
	end

	return string.."%*"
end

--- Create new fold by middle-cliking the range.
local function create_fold(args)
	if foldmarker then
		c("norm! zf"..foldmarker.."G")
		foldmarker = nil
	else
		foldmarker = args.mousepos.line
	end
end

local function fold_click(args, open, other)
	-- Create fold on middle click
	if args.button == "m" then
		create_fold(args)
		if other then return end
	end
	foldmarker = nil

	if args.button == "l" then  -- Open/Close (recursive) fold on (Ctrl)-click
		if open then
			c("norm! z"..(args.mods:find("c") and "O" or "o"))
		else
			c("norm! z"..(args.mods:find("c") and "C" or "c"))
		end
	elseif args.button == "r" then  -- Delete (recursive) fold on (Ctrl)-right click
		c("norm! z"..(args.mods:find("c") and "D" or "d"))
	end
end

--- Handler for clicking '+' in fold column.
local function foldclose_click(args)
	npc(fold_click, args, true)
end

--- Handler for clicking '-' in fold column.
local function foldopen_click(args)
	npc(fold_click, args, false)
end

--- Handler for clicking ' ' in fold column.
local function foldother_click(args)
	npc(fold_click, args, false, true)
end

--- Handler for clicking a Diagnostc* sign.
local function diagnostic_click(args)
	if args.button == "l" then
		d.open_float()       -- Open diagnostic float on left click
	elseif args.button == "m" then
		l.buf.code_action()  -- Open code action on middle click
	end
end

--- Handler for clicking a GitSigns* sign.
local function gitsigns_click(args)
	if args.button == "l" then
		require("gitsigns").preview_hunk()
	elseif args.button == "m" then
		require("gitsigns").reset_hunk()
	elseif args.button == "r" then
		require("gitsigns").stage_hunk()
	end
end

--- Toggle a (conditional) DAP breakpoint.
local function toggle_breakpoint(args)
	local dap = npc(require, "dap")
	if not dap then return end
	if args.mods:find("c") then
		vim.ui.input({ prompt = "Breakpoint condition: " }, function(input)
			dap.set_breakpoint(input)
		end)
	else
		dap.toggle_breakpoint()
	end
end

--- Handler for clicking the line number.
local function lnum_click(args)
	if args.button == "l" then
		-- Toggle DAP (conditional) breakpoint on (Ctrl-)left click
		toggle_breakpoint(args)
	elseif args.button == "m" then
		c("norm! yy")  -- Yank on middle click
	elseif args.button == "r" then
		if args.clicks == 2 then
			c("norm! dd")  -- Cut on double right click
		else
			c("norm! p")   -- Paste on right click
		end
	end
end

M.clickhandlers = {
	Lnum                   = lnum_click,
	FoldClose              = foldclose_click,
	FoldOpen               = foldopen_click,
	FoldOther              = foldother_click,
	DapBreakpointRejected  = toggle_breakpoint,
	DapBreakpoint          = toggle_breakpoint,
	DapBreakpointCondition = toggle_breakpoint,
	DiagnosticSignError    = diagnostic_click,
	DiagnosticSignHint     = diagnostic_click,
	DiagnosticSignInfo     = diagnostic_click,
	DiagnosticSignWarn     = diagnostic_click,
	GitSignsTopdelete      = gitsigns_click,
	GitSignsUntracked      = gitsigns_click,
	GitSignsAdd            = gitsigns_click,
	GitSignsChangedelete   = gitsigns_click,
	GitSignsDelete         = gitsigns_click,
}

return M
