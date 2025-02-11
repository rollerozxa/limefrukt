-- Statistics dialog

local stat = {
	background = { 11, 75, 122 },
	gui = Gui:new()
}

local coolColours

function stat.init()
	stat.gui:add("back", Button:new{
		x = 40, y = 40*15.4,
		w = 40*12, h = 80,
		label = S("Back to main menu"),
		keybind = "escape",
		onClick = function()
			scene.switch("mainmenu")
		end
	})

	coolColours = {colour.random(), colour.random()}
end

local function formatPlaytime(seconds)
	local units = {
		{ "d", 86400 },
		{ "h", 3600 },
		{ "m", 60 },
		{ "s", 1 }
	}

	local results = {}

	for _, unit in ipairs(units) do
		if seconds >= unit[2] then
			local value = math.floor(seconds / unit[2])
			seconds = seconds % unit[2]
			table.insert(results, value .. unit[1])
			if #results == 2 then
				break
			end
		end
	end

	return table.concat(results, ", ")
end

function stat.back()
	scene.switch("mainmenu")
end

local angle = 0

local rows = {
	{
		label = S"Boxes smashed:",
		getValue = function()
			return statistics.get("boxes")
		end,
		onDraw = function(x, y)
			draw.box(x-65, y+17, 40, 40, angle, coolColours[1])
		end
	}, {
		label = S"Balls thrown:",
		getValue = function()
			return statistics.get("balls")
		end,
		onDraw = function(x, y)
			draw.ball(x-65, y+17, angle, coolColours[2])
		end
	}, {
		label = S"Levels unlocked:",
		getValue = function()
			return math.min(savegame.get("levelsUnlocked"), getTotalLevels())
		end,
		onDraw = function(x, y)
			love.graphics.draw(images.lock, x-65, y+17, angle, 0.5, 0.5, 64, 64)
		end
	}, {
		label = S"Levels played:",
		getValue = function()
			return statistics.get("levels")
		end,
		onDraw = function(x, y)
			love.graphics.draw(images.check, x-65, y+17, angle, 0.5, 0.5, 64, 64)
		end
	}, {
		label = S"Total playtime:",
		getValue = function()
			return formatPlaytime(statistics.get("playtime"))
		end,
		onDraw = function(x, y)
			love.graphics.draw(images.timer, x-65, y+17, angle, 0.5, 0.5, 64, 64)
		end
	}
}

function stat.draw()
	love.graphics.setFont(fonts.sans.bigger)
	text.drawOutlined("Statistics", 40, 40, 3)

	love.graphics.setFont(fonts.sans.big)
	for i, row in ipairs(rows) do
		local offset = 150
		local labelwidth = 450

		love.graphics.setColor(love.math.colorFromBytes(9, 54, 87))
		love.graphics.rectangle("fill", 40, 10+i*100, 1000, 75)

		love.graphics.setColor(1,1,1)
		love.graphics.print(row.label, offset, 30+i*100)
		love.graphics.print(row.getValue(), offset+labelwidth, 30+i*100)

		if row.onDraw then
			row.onDraw(offset, 30+i*100)
		end
	end

	angle = angle + math.pi/128
end

return stat
