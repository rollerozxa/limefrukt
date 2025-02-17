-- about.lua: about dialog

local about = {
	background = { 11, 75, 122 },
	gui = Gui:new()
}

local abouttext

function about.init()
	abouttext = love.filesystem.read("data/about.txt") or ""

	about.gui:add("back", Button:new{
		x = 40*1, y = 40*15,
		w = 280, h = 80,
		label = S("Back"),
		keybind = "escape",
		onClick = function()
			scene.switch("mainmenu")
		end,
		isOverlay = true
	})

	about.gui:add("website", Button:new{
		x = 40*14, y = 40*15,
		w = 650, h = 80,
		label = S("Visit boxsmasher.voxelmanip.se"),
		onClick = function()
			love.system.openURL("https://boxsmasher.voxelmanip.se")
		end,
		isOverlay = true
	})
end

function about.back()
	scene.switch("mainmenu")
end

function about.draw()
	love.graphics.setFont(fonts.sans.bigger)
	text.drawOutlined("Box Smasher", 40, 40, 3)

	love.graphics.setFont(fonts.sans.big)
	love.graphics.print(abouttext, 40, 120)

	if dbg.debugEnabled() then
		love.graphics.setColor(1,0,0)
		love.graphics.setFont(fonts.sans.small)
		love.graphics.print("DEBUG", 375, 40)
	end
end

return about
