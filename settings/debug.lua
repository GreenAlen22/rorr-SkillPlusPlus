-- Консольные команды spp_*.

SPP = SPP or {}

local S = SPP.State

local function say(msg)
    Console.print("[spp] "..msg)
end

local function role()
    if Net.client then return "client" end
    if Net.online then return "host" end
    return "offline"
end

local function local_player()
    local p = Player.get_local()
    if not Instance.exists(p) or p.object_index ~= gm.constants.oP then
        say("no local player - start a run first")
        return nil
    end
    return p
end

local SLOT_NAMES = { [0] = "Z", "X", "C", "V" }

Console.new{
    "spp_status",
    {
        "Prints whether Skills++ loaded in full, this machine's network role and "
        .."language, and in a run the local player's points and ranks.",
    },
    function(args)
        local boot = SPP.Boot
        if boot then
            say(string.format("modules %d/%d, missing: %s", boot.loaded, boot.total, boot.missing))
        else
            say("no boot report - main.lua did not reach the end of loading")
        end

        say(string.format("role: %s, packets sent %d, received %d", role(), SPP.Net.sent, SPP.Net.received))

        say("language: "..tostring(gm.translate("SkillPlusPlus.languageCheck")))

        say(string.format("skill descriptions with the upgrade line: %d", SPP.Tooltip.claimed()))

        say(string.format("skills registered by other mods: %d", SPP.Api.count()))

        local level = S.level()
        if not level then
            say("not in a run")
            return
        end

        local interval = S.interval()
        say(string.format("team level %d, a point every %s levels", level,
            interval and tostring(interval) or "? (waiting for the host)"))

        local p = local_player()
        if not p then return end

        local rec  = S.get(p)
        local free = S.free(p)
        say(string.format("points: free %s, spent %d, console bonus %d",
            free and tostring(free) or "?", rec.spent, rec.bonus))

        for slot = 0, 3 do
            local skill = p:get_active_skill(slot).skill
            say(string.format("%s %s: rank %d%s", SLOT_NAMES[slot], skill.identifier,
                rec.rank[slot], S.rankable(p, slot) and "" or " (cannot be ranked)"))
        end

        for _, other in ipairs(S.players()) do
            if other.id ~= p.id then
                local o = S.get(other)
                say(string.format("player %d: Z%d X%d C%d V%d, spent %d, bonus %d",
                    math.floor(tonumber(other.m_id) or 0),
                    o.rank[0], o.rank[1], o.rank[2], o.rank[3], o.spent, o.bonus))
            end
        end
    end
}

Console.new{
    "spp_points [count]",
    {
        "Gives every player extra skill points (1 by default). Host or offline only.",
        {"[count]", "number", "How many points; negative takes them back."},
    },
    function(args)
        if not Net.host then
            say("host only: points are counted by the host")
            return
        end
        if not S.level() then
            say("not in a run")
            return
        end
        local n = math.floor(tonumber(args[1]) or 1)
        S.grant(n)
        say(string.format("granted %d point(s) to every player (%s)", n, role()))
    end
}

SPP.Debug = true
