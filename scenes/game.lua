-- Main game scene

scenes.game = {}

local menuBtn = TexButton:new{
	x = base_resolution.x-(96), y = 0,
	w = 96, h = 110,
	texture = "menu",
	scale = 2.5,
	onClick = function()
		overlay.switch('pause')
	end,
	keybind = 'escape'
}

local restartBtn = Button:new{
	x = 40*23, y = 0,
	w = 40*5.5, h = 40*1.8,
	label = S("Restart"),
	onClick = function()
		scenes.game.init()
	end,
	isVisible = function()
		return game.ballsLeft == 0
	end
}

local lvl

-- Table to store static terrain geometry objects
local terrain = {}
-- Store physics objects of boxes in levels
local boxes = {}
-- Store the current ball's physics object for reference
local ball = nil
-- Amount of boxes in level (decrements when they fall off the level)
local boxNum = 0
-- Total boxes in the level on start
local totalBoxes = 0

-- Misc. joint table (mouse joints and whatnot)
local joints = {}

-- Adds a new hittable box into the world, with proper draw function and
-- physics properties.
local function newBox(x,y,w,h)
	local box = world:newCollider("Rectangle", { x-(w/2),y-(h/2),w,h })
	box:setMass(box:getMass()*0.25)

	box.colour = coolRandomColour()

	function box:draw()
		draw.box(self:getX(), self:getY(), w, h, self:getAngle(), box.colour)
	end

	table.insert(boxes, box)

	boxNum = boxNum + 1
end

-- Keep track of left mouse button state
local helddown = false

local grabbedBall = false

-- Random colour for box HUD
local randc
local randc2

-- Throw vector
local throw = {x = 0, y = 0}

scenes.game.background = { r = 43, g = 64, b = 43 }

function scenes.game.init()
	world = bf.newWorld(0, 90.82*1.5, true)

	-- Reset variables
	terrain = {}
	boxes = {}
	ball = nil
	boxNum = 0
	totalBoxes = 0
	joints = {}
	helddown = false
	grabbedBall = false

	randc = coolRandomColour()

	-- Load level
	lvl = loadstring(love.filesystem.read("levels/"..game.level..".lua"))()

	game.ballsLeft = lvl.ballsLeft or 99

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

		rect.colour = ter.colour or { 125/256, 227/256, 102/256 }
		local friction = ter.friction or 0.5
		local restitution = ter.restitution or 0.33

		rect.fixture:setFriction(friction)
		rect.fixture:setRestitution(restitution)

		function rect:draw()
			-- no-op
		end

		table.insert(terrain, rect)
	end

	-- Iterate over box clusters and create the boxes within them
	for _, clust in ipairs(lvl.boxclusters) do
		for x = 1, clust.aX, 1 do
			for y = 1, clust.aY, 1 do
				newBox(clust.x + (x * clust.w), clust.y + (y * clust.h), clust.w, clust.h)
			end
		end
	end

	totalBoxes = boxNum

	randc2 = coolRandomColour()
end

function scenes.game.update(dt)
	menuBtn:update()
	restartBtn:update()

	if overlay.isActive() or scene.isTransitioning() then return end

	if not dbg.phys_pause.enabled then
		world:update(dt)
	end

	-- Ball throwing code. When holding down mouse...
	if love.mouse.isDown(1) and game.ballsLeft > 0 then
		-- Get mouse position, convert it from the scaled screen resolution
		-- to internal coordinates.
		local mx, my = unscaled(love.mouse.getPosition())

		-- Check if cursor is within the throw boundary. You can only create boxes inside the boundary,
		-- *but* you should be able to drag it out outside of the boundary.
		local bndry = lvl.throwBoundary
		local withinBoundary = checkCollision(mx,my,5,5, bndry.x, bndry.y, bndry.w, bndry.h)
		if (withinBoundary and not oldmousedown) or grabbedBall then
			-- Just started holding the mouse? Create a ball at the mouse's position,
			-- add a mouse joint to keep it static until thrown.
			if not helddown then
				sounds.spawn:clone():play()

				ball = world:newCollider("Circle", {mx, my, 30})
				-- Set the thrown object to a "bullet", which uses more detailed collision detection
				-- to prevent it jumping over bodies if the velocity is high enough
				ball:setBullet(true)

				ball.colour = coolRandomColour()
				ball.debug_step = 0

				function ball:draw()
					draw.ball(self:getX(), self:getY(), self:getAngle(), ball.colour)
				end

				joints.boxMouse = love.physics.newMouseJoint(ball.body, mx, my)
				joints.boxMouse:setTarget(mx, my)

				-- We now have a ball grabbed, don't boundary check anymore.
				grabbedBall = true
			end

			if ball then
				-- Now we're holding it down...
				helddown = true

				-- Calculate "throw vector", like a slingshot. It is inverse of the vector
				-- that is the difference in coordinates between the created ball and mouse.
				local ox, oy = ball:getPosition()
				throw.x = -(mx-ox)
				throw.y = -(my-oy)
			end
		end

	-- When helddown is true, but mouse is not held (i.e. mouse has been released, we're throwing it!)
	elseif helddown and joints.boxMouse then
		-- Destroy mouse joint, don't make it static anymore.
		joints.boxMouse:destroy()
		helddown = false
		grabbedBall = false
		game.ballsLeft = game.ballsLeft - 1

		sounds.throw:clone():play()

		statistics.add("balls", 1)

		-- Apply a linear impulse with the throw vector that makes the ball go wheee
		-- (hopefully crashing into some boxes ^^)
		ball:applyLinearImpulse(throw.x*30, throw.y*30)
	end

	for key, box in pairs(boxes) do
		if outOfBounds(box:getPosition()) then
			box:destroy()
			boxes[key] = nil
			boxNum = boxNum - 1
			sounds.pop:clone():play()
			statistics.add('boxes', 1)
		end
	end

	if tableEmpty(boxes) then
		statistics.add("levels", 1)
		if game.level == game.totalLevels then
			overlay.switch('final')
		else
			overlay.switch('success')
		end
	end

	if mouseClick() and not game.seenTutorial then
		game.seenTutorial = true
		savegame.set("seenTutorial", true)
	end
end

function scenes.game.draw()
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
		love.graphics.setColor(ter.colour or { 125/256, 227/256, 102/256 })
		love.graphics.rectangle('fill', ter.x, ter.y, ter.w, ter.h)
	end

	-- If holding down, show the throw vector.
	if ball and helddown then
		local ox, oy = ball:getPosition()
		love.graphics.setColor(1,0,0)
		love.graphics.arrow(ox, oy, ox+throw.x, oy+throw.y, 10, math.pi/4)
	end

	love.graphics.setFont(fonts.sans.medium)

	love.graphics.setColor(randc.r, randc.g, randc.b)
	love.graphics.rectangle('fill', 10, 10, 40, 40)
	love.graphics.setColor(0,0,0)
	love.graphics.rectangle('line', 10, 10, 40, 40)

	love.graphics.setColor(1,1,1)

	love.graphics.print(string.format("%d/%d (%d%%)", boxNum, totalBoxes, (boxNum/totalBoxes)*100), 60, 15)

	love.graphics.setLineWidth(4)
	draw.ball(30, 80, 0, randc2, 25)

	if game.ballsLeft < 1 then
		love.graphics.setColor(1,0,0)
	else
		love.graphics.setColor(1,1,1)
	end

	love.graphics.print(string.format("x%d", game.ballsLeft), 60, 70)

	menuBtn:draw()
	restartBtn:draw()

	if not game.seenTutorial then
		love.graphics.setColor(1,1,1)
		love.graphics.draw(images.tutorial, 0, 0, 0, 1, 1)

		love.graphics.setFont(fonts.sans.big)
		love.graphics.print("Tap and drag\nto shoot...", 40*7, 40*3)
	end
end
