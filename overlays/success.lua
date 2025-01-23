-- Level completion overlay

overlays.success = {}

local level

local backBtn = Button:new{
	x = 390, y = 540,
	w = 200, h = 96,
	label = S("Back"),
	onClick = function()
		overlay.switch(false)
		scene.switch("selectlevel")
	end,
	isOverlay = true
}

local nextBtn = Button:new{
	x = 620, y = 540,
	w = 270, h = 96,
	label = S("Next level"),
	onClick = function()
		overlay.switch(false)
		scene.switch("game", {level = level + 1})
	end,
	isOverlay = true
}

local ballsUsed, totalBalls

function overlays.success.init(data)
	sounds.success:clone():play()

	level = data.level
	ballsUsed = data.ballsUsed
	totalBalls = data.totalBalls
end

function overlays.success.back()
	overlay.switch(false)
	scene.switch("selectlevel")
end

function overlays.success.update()
	backBtn:update()
	nextBtn:update()
end

function overlays.success.draw()
	love.graphics.setColor(64/255, 120/255, 161/255,0.9)
	love.graphics.rectangle('fill', 380, 20, 520, 680)

	love.graphics.setColor(1,1,1,1)
	love.graphics.setFont(fonts.sans.bigger)
	drawCenteredText(4, 64, base_resolution.x, 64, S("Level Complete!"))

	local texts = {
		S("Level: %d", level),
		S("Balls used: %d/%d", ballsUsed, totalBalls)
	}

	love.graphics.setFont(fonts.sans.medium)
	for i = 1, #texts, 1 do
		love.graphics.print(texts[i], 420, 4*32+(i*72))
	end

	backBtn:draw()
	nextBtn:draw()
end
