-- Minimap icon and addon compartment entry, both driven by one LibDataBroker object.
--   Left-click   toggle the review panel
--   Right-click  menu: count badge on/off, add rule, options

local ADDON, ns = ...
local MinimapIcon = {}
ns.Minimap = MinimapIcon

local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")

local function openMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(ADDON)
        root:CreateCheckbox("Count badge", function() return ns.db.badge end, function()
            ns.SetOption("badge", not ns.db.badge)
        end)
        root:CreateButton("Add rule…", function() ns.RuleDialog.Open() end)
        root:CreateButton("Options", ns.Options.Open)
    end)
end

local broker = LDB:NewDataObject(ADDON, {
    type = "launcher",
    label = ADDON,
    text = "0",
    icon = "Interface\\Icons\\INV_Misc_Bag_10",
    OnClick = function(owner, button)
        if button == "RightButton" then openMenu(owner) else ns.Panel.Toggle() end
    end,
    OnTooltipShow = function(tooltip)
        local count = #ns.state.items
        tooltip:AddLine(ADDON)
        tooltip:AddLine(count == 1 and "1 item safe to delete" or ("%d items safe to delete"):format(count), 1, 1, 1)
        tooltip:AddLine(" ")
        tooltip:AddLine("Left-click: review items", 0.6, 0.6, 0.6)
        tooltip:AddLine("Right-click: add rule, badge, options", 0.6, 0.6, 0.6)
    end,
})

function MinimapIcon.SetShown(show)
    ns.db.minimap.hide = not show
    if show then DBIcon:Show(ADDON) else DBIcon:Hide(ADDON) end
end

ns.Listen("Loaded", function()
    DBIcon:Register(ADDON, broker, ns.db.minimap)
    DBIcon:AddButtonToCompartment(ADDON)
    ns.Badge.Attach(DBIcon:GetMinimapButton(ADDON))
end)

ns.Listen("Scanned", function() broker.text = tostring(#ns.state.items) end)
