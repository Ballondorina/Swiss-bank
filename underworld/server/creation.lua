-- ============================================================
-- UNDERWORLD — Server: Player-Paid Org Creation
-- ============================================================

-- ============================================================
-- VALIDATION HELPERS
-- ============================================================

local function IsValidOrgName(name)
    -- 3-24 chars, alphanumeric + spaces, must start with letter
    if not name then return false end
    if #name < 3 or #name > 24 then return false end
    if not name:match('^[A-Za-z][A-Za-z0-9 ]*$') then return false end
    return true
end

local function IsValidLabel(label)
    if not label then return false end
    if #label < 3 or #label > 48 then return false end
    return true
end

-- ============================================================
-- GET CREATION FEES — sends config to client for UI display
-- ============================================================

RegisterNetEvent('underworld:server:getCreationFees', function()
    local src = source
    TriggerClientEvent('underworld:client:creationFees', src, {
        fees               = Config.CreationFees,
        requiresApproval   = Config.RequireAdminApproval,
        orgTypes           = {
            legal   = Config.OrgTypes.legal.label,
            illegal = Config.OrgTypes.illegal.label,
            family  = Config.OrgTypes.family.label
        }
    })
end)

-- ============================================================
-- CREATE ORG — player-paid flow
-- ============================================================

RegisterNetEvent('underworld:server:createOrg', function(data)
    local src       = source
    local citizenId = GetCitizenId(src)
    if not citizenId then return end

    local Player = GetQBPlayer(src)
    if not Player then return end

    -- Parse + validate input
    local name    = tostring(data.name    or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local label   = tostring(data.label   or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local orgType = tostring(data.orgType or '')

    if not IsValidOrgName(name) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Invalid org name. Use 3–24 alphanumeric characters.'
        })
        TriggerClientEvent('underworld:client:creationResult', src, { success = false })
        return
    end

    if not IsValidLabel(label) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Invalid label. Use 3–48 characters.'
        })
        TriggerClientEvent('underworld:client:creationResult', src, { success = false })
        return
    end

    if not Config.OrgTypes[orgType] then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Invalid organization type.'
        })
        TriggerClientEvent('underworld:client:creationResult', src, { success = false })
        return
    end

    -- Check player not already in an org
    local existing = MySQL.scalar.await('SELECT id FROM uw_members WHERE citizen_id = ?', { citizenId })
    if existing then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'You must leave your current organization before founding a new one.'
        })
        TriggerClientEvent('underworld:client:creationResult', src, { success = false })
        return
    end

    -- Check name uniqueness
    local nameExists = MySQL.scalar.await(
        'SELECT id FROM uw_organizations WHERE name = ?',
        { name:lower() }
    )
    if nameExists then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'An organization with that name already exists.'
        })
        TriggerClientEvent('underworld:client:creationResult', src, { success = false })
        return
    end

    -- Check funds
    local fee = Config.CreationFees[orgType] or 500000
    local bankBalance = Player.PlayerData.money['bank'] or 0

    if bankBalance < fee then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('Insufficient funds. You need $%s in your bank account.'):format(fee)
        })
        TriggerClientEvent('underworld:client:creationResult', src, { success = false })
        return
    end

    -- Deduct fee
    Player.Functions.RemoveMoney('bank', fee, 'underworld-org-creation')

    -- Create the organization
    local orgId = MySQL.insert.await(
        'INSERT INTO uw_organizations (name, label, type, tier, xp, level) VALUES (?, ?, ?, 1, 0, 1)',
        { name:lower(), label, orgType }
    )

    if not orgId then
        -- Refund on failure
        Player.Functions.AddMoney('bank', fee, 'underworld-org-creation-refund')
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Failed to create organization. Your funds have been refunded.'
        })
        TriggerClientEvent('underworld:client:creationResult', src, { success = false })
        return
    end

    -- Set player as Direktör
    MySQL.insert.await(
        'INSERT INTO uw_members (org_id, citizen_id, name, rank) VALUES (?, ?, ?, 5)',
        { orgId, citizenId, GetPlayerName(src) }
    )

    -- Register shared stash for this org
    if GetResourceState('ox_inventory') == 'started' then
        local slots  = GetStashSlots(1, 1)
        local weight = GetStashWeight(1)
        exports.ox_inventory:RegisterStash(
            ('uw_stash_%d'):format(orgId),
            ('%s — Org Stash'):format(label),
            slots,
            weight
        )
    end

    -- Log creation
    MySQL.insert.await(
        'INSERT INTO uw_creation_log (org_id, citizen_id, fee_paid) VALUES (?, ?, ?)',
        { orgId, citizenId, fee }
    )

    -- Add ledger entry
    AddLedger(orgId, citizenId, 'org_creation', -fee, 'Organization founding fee')

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = ('Welcome, Direktör. %s has been founded.'):format(label)
    })

    TriggerClientEvent('underworld:client:creationResult', src, { success = true, orgId = orgId })

    print(('[UNDERWORLD] %s (CID: %s) founded org "%s" (type: %s, fee: $%s)'):format(
        GetPlayerName(src), citizenId, label, orgType, fee))
end)

-- ============================================================
-- PENDING APPROVAL FLOW (if Config.RequireAdminApproval = true)
-- ============================================================

RegisterCommand('uwapproveorg', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(tostring(source), 'command.uwcreateorg') then
        if source ~= 0 then
            TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'No permission.' })
        end
        return
    end

    local orgId = tonumber(args[1])
    if not orgId then
        print('[UNDERWORLD] Usage: /uwapproveorg <orgId>')
        return
    end

    MySQL.update.await(
        "UPDATE uw_organizations SET name = REPLACE(name, '_pending', '') WHERE id = ?",
        { orgId }
    )
    print(('[UNDERWORLD] Org %d approved.'):format(orgId))
end, true)
