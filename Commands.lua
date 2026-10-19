local _, DBR = ...

local USAGE = "Use /dbr (the settings, with the buff reminders and cooldown chimes), /dbr unlock, /dbr lock, "
    .. "/dbr reset, or /dbr debug."
local UNAVAILABLE = "Dyre's Buff Reminders is unavailable. Check the DBR login message."

-- Each command is one word; "" opens the settings. Handlers live in Core and
-- Options. Diagnostics also run when DBR is unavailable, to help explain why.
local COMMANDS = {
    [""] = {handler = "OpenSettings"},
    options = {handler = "OpenSettings"},
    unlock = {handler = "Unlock"},
    lock = {handler = "Lock"},
    reset = {handler = "ResetPositions"},
    debug = {handler = "ReportDebug", always = true},
}

function DBR.ParseCommand(message)
    if type(message) ~= "string" then
        return nil, USAGE
    end
    local command = message:match("^%s*(.-)%s*$"):lower()
    if command:find("%s") or not COMMANDS[command] then
        return nil, USAGE
    end
    return command
end

function DBR.HandleCommand(message)
    local command, usage = DBR.ParseCommand(message)
    if not command then
        DBR.Report(usage)
        return
    end
    local entry = COMMANDS[command]
    if not DBR.available and not entry.always then
        DBR.Report(UNAVAILABLE)
        return
    end
    DBR[entry.handler]()
end
