--heroturrets = { util = get_liborio() }
heroturrets = { }

data:extend({
	{
		type = "sound",
		name = "heroturrets-rank-up-sound",
		filename = "__HeroTurretsReduxFork__/sound/rank-up-promotion.ogg",
		volume = 1.0
	}
})

-- Informatron in-game wiki pages (only registers images if Informatron is present and loaded first,
-- guaranteed by the "? informatron" optional dependency in info.json).
if mods["informatron"] then
	for i = 1, 6 do
		---@diagnostic disable-next-line: undefined-global
		informatron_make_image(
			"heroturrets_rank_icon_" .. i,
			"__HeroTurretsReduxFork__/graphics/icons/hero-" .. i .. "-icon.png",
			64, 64
		)
	end
end

