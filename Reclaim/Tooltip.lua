-- Tooltip: adds "Reclaim: safe to delete" and the reason to item tooltips.

local _, ns = ...

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if not ns.db or not data or not data.id then return end
    if issecretvalue and issecretvalue(data.id) then return end
    local reason = ns.Scanner.Reason(data.id)
    if not reason then return end
    tooltip:AddLine(" ")
    tooltip:AddLine("Reclaim: safe to delete", 0.25, 1, 0.25)
    tooltip:AddLine(reason, 0.6, 0.6, 0.6, true)
    tooltip:AddLine(" ")
end)
