--[=[
  DojutsuLegality.luau

  Call this before adding Dojutsu. Before Serialize writes to the DataStore.

  Validates whether a given DojutsuInventory (and its accompanying MissingEyes
  state) represents a legally possible configuration of Dōjutsu -- i.e. checks
  that no Shinobi can end up in an impossible eye state (both eyes missing,
  a Binocular mixed with a Monocular, the same Dōjutsu split illegally across
  both eyes, etc.).

  Works by scanning for a small set of known-illegal conditions (see the
  LEGAL/ILLEGAL FORMAT reference below); a DojutsuInventory is considered legal
  only if none of them are found. 
  
  **Use Tests.IsLegal() as the single entry point --**
  the individual Tests.* functions are exposed separately so each illegal
  condition can also be checked (or tested) in isolation.

]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Types.Inventory);

local Tests: Tests = {};

type Tests = {

    IsLegal: (DojutsuInventory: Types.DojutsuInventory) -> boolean;
    BothEyesMissing: (DojutsuInventory: Types.DojutsuInventory) -> boolean;
    MissingEyeConflictsWithEntry: (DojutsuInventory: Types.DojutsuInventory) -> boolean
}

--[=[
    Splits an Eye key (e.g. "Sharingan_Left", "Sharingan_Left_MS") into its
    DojutsuType and full suffix (e.g. "Sharingan", "_Left" / "_Left_MS").
    Splits only on the FIRST underscore, so "_Left_MS"/"_Right_MS" survive intact.
]=]
function Tests.SplitEyeKey(Eye: string): (Types.DojutsuType, string)
    local underscoreIndex = Eye:find("_")
    local DojutsuType = Eye:sub(1, underscoreIndex - 1)
    local DojutsuSuffix = Eye:sub(underscoreIndex) -- includes the leading "_"
    return DojutsuType, DojutsuSuffix
end


--[=[
    MAIN TEST:

    Runs every illegal check against a DojutsuInventory. Returns true only if
    NONE of the illegal conditions are found (i.e. the inventory is legal).
]=]
function Tests.IsLegal(DojutsuInventory: Types.DojutsuInventory): boolean
    if Tests.BothEyesMissing(DojutsuInventory) then
        warn("DojutsuLegality: illegal state -- BothEyesMissing");
        return false;
    end
    if Tests.MissingEyeConflictsWithEntry(DojutsuInventory) then
        warn("DojutsuLegality: illegal state -- MissingEyeConflictsWithEntry");
        return false;
    end
    if Tests.SameDojutsuSplitAcrossMonoculars(DojutsuInventory) then
        warn("DojutsuLegality: illegal state -- SameDojutsuSplitAcrossMonoculars");
        return false;
    end
    if Tests.BinocularMixedWithAnyOtherEntry(DojutsuInventory) then
        warn("DojutsuLegality: illegal state -- BinocularMixedWithAnyOtherEntry");
        return false;
    end
    if Tests.TooManyEyeSlotsClaimed(DojutsuInventory) then
        warn("DojutsuLegality: illegal state -- TooManyEyeSlotsClaimed");
        return false;
    end

    return true;
end

--[=[
    ILLEGAL CHECK 1: Both eyes missing.
]=]
function Tests.BothEyesMissing(DojutsuInventory: Types.DojutsuInventory): boolean
    local MissingEyes = DojutsuInventory.MissingEyes;
    return MissingEyes.Left == true and MissingEyes.Right == true;
end

--[=[
    ILLEGAL CHECK 2: A side is marked missing, but a real Dōjutsu entry
    also claims that same side.
]=]
function Tests.MissingEyeConflictsWithEntry(DojutsuInventory: Types.DojutsuInventory): boolean
    local MissingEyes = DojutsuInventory.MissingEyes;
    -- FIX: was iterating DojutsuInventory itself (the wrapper), not DojutsuInventory.Inventory
    -- (the actual eye-keyed table) -- would have looped over {Inventory=..., MissingEyes=...}
    -- instead of real entries.
    for Eye, Properties in pairs(DojutsuInventory.Inventory) do
        local DojutsuType, DojutsuSuffix = Tests.SplitEyeKey(Eye);

        if MissingEyes.Left and (DojutsuSuffix == "_Left" or DojutsuSuffix == "_Left_MS" or DojutsuSuffix == "_Both") then
            return true;
        end
        if MissingEyes.Right and (DojutsuSuffix == "_Right" or DojutsuSuffix == "_Right_MS" or DojutsuSuffix == "_Both") then
            return true;
        end
    end
    return false;
end

--[=[
    ILLEGAL CHECK 3: The same Dōjutsu type appears as two separate Monoculars
    (A_Left + A_Right) instead of being stored as a single A_Both.
    Exception: Sharingan_Left_MS + Sharingan_Right_MS is explicitly legal.
]=]
function Tests.SameDojutsuSplitAcrossMonoculars(DojutsuInventory: Types.DojutsuInventory): boolean
    local seenLeft: {[Types.DojutsuType]: boolean} = {};
    local seenRight: {[Types.DojutsuType]: boolean} = {};

    for Eye, Properties in pairs(DojutsuInventory.Inventory) do
        local DojutsuType, DojutsuSuffix = Tests.SplitEyeKey(Eye);

        if DojutsuSuffix == "_Left" then
            seenLeft[DojutsuType] = true;
        elseif DojutsuSuffix == "_Right" then
            seenRight[DojutsuType] = true;
        end
        -- Note: "_Left_MS"/"_Right_MS" are intentionally excluded from this check --
        -- Sharingan_Left_MS + Sharingan_Right_MS is the explicit legal exception.
    end

    for DojutsuType in pairs(seenLeft) do
        if seenRight[DojutsuType] then
            return true;
        end
    end
    return false;
end

--[=[
    ILLEGAL CHECK 4: A Binocular (_Both) coexists with any other entry
    (whether that entry is the same type or a different one).
]=]
function Tests.BinocularMixedWithAnyOtherEntry(DojutsuInventory: Types.DojutsuInventory): boolean
    local totalEntries = 0;
    local hasBoth = false;

    for Eye, Properties in pairs(DojutsuInventory.Inventory) do
        local DojutsuType, DojutsuSuffix = Tests.SplitEyeKey(Eye);
        totalEntries += 1;
        if DojutsuSuffix == "_Both" then
            hasBoth = true;
        end
    end

    return hasBoth and totalEntries > 1;
end

--[=[
    ILLEGAL CHECK 5: More than 2 total eye-slots are claimed across all entries
    (a _Both counts as 2, everything else counts as 1). Catches malformed/corrupted
    data that doesn't fit any of the more specific checks above.
]=]
function Tests.TooManyEyeSlotsClaimed(DojutsuInventory: Types.DojutsuInventory): boolean
    local MissingEyes = DojutsuInventory.MissingEyes;
    local slotsClaimed = 0;

    for Eye, Properties in pairs(DojutsuInventory.Inventory) do
        local DojutsuType, DojutsuSuffix = Tests.SplitEyeKey(Eye);
        if DojutsuSuffix == "_Both" then
            slotsClaimed += 2;
        else
            slotsClaimed += 1;
        end
    end

    if MissingEyes.Left then
        slotsClaimed += 1;
    end
    if MissingEyes.Right then
        slotsClaimed += 1;
    end

    return slotsClaimed > 2;
end



return Tests :: Tests;




--[[
LEGAL FORMAT:
    No Dojutsu:
    ()

    For any Dōjutsu "A":
    (A_Left)
    (A_Right)
    (A_Both)

    (Sharingan_Left_MS)
    (Sharingan_Right_MS)

    For any two Dōjutsu "A" and "B" where A ≠ B:
    (A_Left + B_Right)
    (A_Right + B_Left)

    (Sharingan_Left_MS + Sharingan_Right_MS)

    MissingEyes = {
        Left = true;
        Right = false;
    }

    MissingEyes = {
        Left = false;
        Right = true;
    }


ILLEGAL FORMAT:
    For any Dōjutsu "A":
    (A_Left + A_Right)

    For any two Dōjutsu "A" and "B" where A ≠ B:
    (A_Both + B_Left)
    (A_Both + B_Right)

    MissingEyes = {
        Left = true;
        Right = true'
    }
]]