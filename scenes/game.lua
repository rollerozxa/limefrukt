-- Main game scene

local game = {
	background = { 43, 64, 43 },
	gui = Gui:new()
}

local terrain, boxes, boxNum, totalBoxes, joints, grabbedBall
local randc, randc2
local level, lvl, ballsLeft, seenTutorial
local throw = {x = 0, y = 0}
local step

-- Adds a new hittable box into the world, with proper draw function and
-- physics properties.
local function newBox(x, y, w, h)
	local box = world:newCollider("Rectangle", { x - (w / 2), y - (h / 2), w, h })
	box:setMass(box:getMass() * 0.25)

	box.colour = colour.random()

	function box:draw()
		draw.box(self:getX(), self:getY(), w, h, self:getAngle(), box.colour)
	end

	table.insert(boxes, box)

	boxNum = boxNum + 1
end

function game.init(data)
	game.gui:add("menu", TexButton:new{
		x = resolution.x - (96), y = 0,
		w = 96, h = 110,
		texture = "menu",
		scale = 2.5,
		onClick = function()
			overlay.switch('pause')
		end,
		keybind = 'escape'
	})

	game.gui:add("restart", Button:new{
		x = 40*23, y = 0,
		w = 40*5.5, h = 40*1.8,
		label = S("Restart"),
		onClick = function()
			scene.restart(true)
		end,
		isVisible = function()
			return ballsLeft == 0
		end
	})

	world = bf.World:new(0, 90.82*1.5, true)

	step = 0

	-- Reset variables
	terrain = {}
	boxes = {}
	boxNum = 0
	totalBoxes = 0
	joints = {}
	grabbedBall = nil

	randc = colour.random()

	-- Load level
	level = data.level or 1
	lvl = loadstring(love.filesystem.read("levels/"..level..".lua"))()

	ballsLeft = lvl.totalBalls or 99

	seenTutorial = savegame.get("seenTutorial")

	-- Iterate over terrain objects and create static colliders for them
	for _, ter in pairs(lvl.terrain) do
		-- Box2D works with the center of mass (for rectangles they're in the middle of the rectangle),
		-- but level definition works with rectangles with origin being top left. We need to convert these.
		local dim = {
			ter.x+(ter.w/2),
			ter.y+(ter.h/2),
			ter.w, ter.h}

		-- Make a static collider with the dimensions of the terrain object
		local rect = world:newCollider("Rectangle", dim)
		rect:setType("static")

		ter.colour = { love.math.colorFromBytes(unpack(ter.colour or {125, 227, 102})) }

		rect.fixture:setFriction(ter.friction or 0.5)
		rect.fixture:setRestitution(ter.restitution or 0.33)

		function rect:draw()
			-- no-op
		end

		table.insert(terrain, rect)
	end

	-- Iterate over box clusters and create the boxes within them
	for _, clust in ipairs(lvl.boxclusters) do
		for x = 1, (clust.aX or 1), 1 do
			for y = 1, (clust.aY or 1), 1 do
				newBox(clust.x + (x * clust.w), clust.y + (y * clust.h), clust.w, clust.h)
			end
		end
	end

	totalBoxes = boxNum

	randc2 = colour.random()
end

function game.back()
	overlay.switch("pause")
end

function game.update(dt)
	if overlay.isActive() or scene.isTransitioning() then return end

	if dbg.isEnabled('autorestart') then
		step = step + dt

		if step > 1 then
			scene.restart(true)
		end
	end

	if not dbg.isEnabled('phys_pause') then
		-- Cap physics to dt=0.02 to prevent physics collapse, equiv. to 50fps
		world:update(math.min(dt, 0.02))
	end

	-- Ball throwing code. When holding down mouse...
	if love.mouse.isDown(1) and ballsLeft > 0 then
		-- Get mouse position, convert it from the scaled screen resolution
		-- to internal coordinates.
		local mx, my = unscaled(love.mouse.getPosition())

		-- Check if cursor is within the throw boundary. You can only create boxes inside the boundary,
		-- *but* you should be able to drag it out outside of the boundary.
		local bndry = lvl.throwBoundary
		local withinBoundary = checkCollision(mx,my,5,5, bndry.x, bndry.y, bndry.w, bndry.h)
		if withinBoundary and not oldmousedown and not grabbedBall then
			-- Just started holding the mouse? Create a ball at the mouse's position,
			-- add a mouse joint to keep it static until thrown.
			sound.play("spawn")

			local ball = world:newCollider("Circle", {mx, my, 30})
			-- Set the thrown object to a "bullet", which uses more detailed collision detection
			-- to prevent it jumping over bodies if the velocity is high enough
			ball:setBullet(true)

			ball.colour = colour.random()

			function ball:draw()
				draw.ball(self:getX(), self:getY(), self:getAngle(), self.colour)
			end

			joints.boxMouse = love.physics.newMouseJoint(ball.body, mx, my)
			joints.boxMouse:setTarget(mx, my)

			-- We now have a ball grabbed, don't boundary check anymore.
			grabbedBall = ball
		end
		if grabbedBall then
			-- Now we're holding it down...
			-- Calculate "throw vector", like a slingshot. It is inverse of the vector
			-- that is the difference in coordinates between the created ball and mouse.
			local ox, oy = grabbedBall:getPosition()
			throw.x = -(mx-ox)
			throw.y = -(my-oy)
		end

		-- When grabbedBall is defined, but mouse is not held (i.e. mouse has been released, we're throwing it!)
	elseif grabbedBall and joints.boxMouse then
		-- Destroy mouse joint, don't make it static anymore.
		joints.boxMouse:destroy()
		ballsLeft = ballsLeft - 1

		sound.play("throw")

		statistics.add("balls", 1)

		-- Apply a linear impulse with the throw vector that makes the ball go wheee
		-- (hopefully crashing into some boxes ^^)
		grabbedBall:applyLinearImpulse(throw.x * 30, throw.y * 30)
		grabbedBall = nil
	end

	for key, box in pairs(boxes) do
		if outOfBounds(box:getPosition()) then
			box:destroy()
			boxes[key] = nil
			boxNum = boxNum - 1
			sound.play("pop")
			statistics.add('boxes', 1)
		end
	end

	if tableEmpty(boxes) then
		statistics.add("levels", 1)

		-- If this is the latest level, unlock the next level.
		local levelsUnlocked = savegame.get("levelsUnlocked")
		if level == levelsUnlocked then
			levelsUnlocked = levelsUnlocked + 1
			savegame.set('levelsUnlocked', levelsUnlocked)
		end

		overlay.switch(level == getTotalLevels() and 'final' or 'success', {
			level = level,
			ballsUsed = lvl.totalBalls - ballsLeft,
			totalBalls = lvl.totalBalls
		})
	end

	if mouseClick() and not seenTutorial then
		seenTutorial = true
		savegame.set("seenTutorial", true)
	end
end

function game.draw()
	love.graphics.setLineWidth(2)
	love.graphics.setColor(1,1,1)

	-- Draw physics objects using Breezefield.
	world:draw()

	-- Draw the throw boundary
	local bndry = lvl.throwBoundary
	love.graphics.setLineWidth(5)
	love.graphics.rectangle('line', bndry.x, bndry.y, bndry.w, bndry.h)
	love.graphics.setLineWidth(2)

	-- Draw terrain rectangles (Breezefield is able to draw them itself but
	-- getting the representation of a Box2D shape is weird, just do it ourself).
	for _, ter in pairs(lvl.terrain) do
		love.graphics.setColor(ter.colour)
		love.graphics.rectangle('fill', ter.x, ter.y, ter.w, ter.h)
	end

	-- If holding down, show the throw vector.
	if grabbedBall then
		local ox, oy = grabbedBall:getPosition()
		love.graphics.setColor(1,0,0)
		draw.arrow(ox, oy, ox+throw.x, oy+throw.y, 10, math.pi/4)
	end

	love.graphics.setFont(fonts.sans.medium)

	love.graphics.setColor(randc)
	love.graphics.rectangle('fill', 10, 10, 40, 40)
	love.graphics.setColor(0,0,0)
	love.graphics.rectangle('line', 10, 10, 40, 40)

	love.graphics.setColor(1,1,1)

	love.graphics.print(string.format("%d/%d (%d%%)", boxNum, totalBoxes, (boxNum/totalBoxes)*100), 60, 15)

	love.graphics.setLineWidth(4)
	draw.ball(30, 80, 0, randc2, 25)

	if ballsLeft < 1 then
		love.graphics.setColor(1,0,0)
	else
		love.graphics.setColor(1,1,1)
	end

	love.graphics.print(string.format("x%d", ballsLeft), 60, 70)

	if not seenTutorial then
		love.graphics.setColor(1,1,1)
		love.graphics.draw(images.tutorial, 0, 0, 0, 1, 1)

		love.graphics.setFont(fonts.sans.big)
		love.graphics.print("Tap and drag\nto shoot...", 40*7, 40*3)
	end
end

return game
