--!strict
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")

local main = script.Parent
local gridSpace = main:WaitForChild("Grid")
local loseScreen = main:WaitForChild("Lose")
local restart = loseScreen:WaitForChild("Restart")
local loseHighScore = loseScreen:WaitForChild("HighScore")
local loseApples = loseScreen:WaitForChild("Apples")
local apples = main:WaitForChild("Apples")
local highScore = main:WaitForChild("HighScore")
local play = main:WaitForChild("Play")
local grid: { { string } } = {}

local images: { [string]: string } = {
	apple_ID = "rbxassetid://115782078"
}

local sounds: { [string]: Sound } = {
	eatSound = script:WaitForChild("Eat")
}

-- SETTINGS
-- 25 x 25 grid
local GRID_X = 25
local GRID_Y = 25
local SHIFT_TIME = 0.1
local START_LENGTH = 3

local scaleX = 1 / GRID_X
local scaleY = 1 / GRID_Y
local squareSize = UDim2.fromScale(scaleX, scaleY)

local function preloadAssets()
	local assets = {}
	for _, img in images do
		local imageLabel = Instance.new("ImageLabel")
		imageLabel.Image = img
		imageLabel.ZIndex = 0
		imageLabel.Parent = main
		table.insert(assets, imageLabel)
	end
	for _, sound in sounds do
		table.insert(assets, sound)
	end
	pcall(function()
		ContentProvider:PreloadAsync(assets)
	end)
end

-- We store x and y in the grid starting from 1 because luau arrays start at 1,
-- but we will position the squares on the grid starting from (0, 0), so we will do (x - 1, y - 1)
local function make2DGrid()
	for x = 1, GRID_X do
		table.insert(grid, {} :: { string })
		local brightSquare = (x % 2 == 1)
		for y = 1, GRID_Y do
			local square = Instance.new("Frame")
			square.Name = "square"
			square.ZIndex = 2
			square.BackgroundColor3 = if brightSquare then Color3.fromRGB(171, 255, 146) else Color3.fromRGB(99, 147, 84)
			square.Size = squareSize
			-- X - 1 so it will start at (0, 0)
			square.Position = UDim2.fromScale(scaleX * (x - 1), scaleY * (y - 1))
			square.BorderSizePixel = 0
			square.Parent = gridSpace
			table.insert(grid[x], "Empty")
			brightSquare = not brightSquare
		end
	end
end

local playing = false
local currentApples = 0
local currentHighScore = 0
local currentApple: { X: number, Y: number, Apple: ImageLabel }?

type SnakePart = { X: number, Y: number, Part: Frame }
type Snake = { SnakePart }
local function startGame(endGame: (Snake, { RBXScriptConnection }) -> ())
	play.Text = "Playing..."
	
	local snake: Snake = {}
	local direction = { X = 0, Y = 1 }
	local conns: { RBXScriptConnection } = {}
	
	local function spawnApple()
		-- Destroy previous apple
		if currentApple then
			currentApple.Apple:Destroy()
			grid[currentApple.X][currentApple.Y] = "Empty"
		end

		local apple = Instance.new("ImageLabel")
		apple.Size = squareSize
		apple.Image = images.apple_ID
		apple.BackgroundTransparency = 1
		apple.BorderSizePixel = 0
		apple.ZIndex = 3

		while true do
			local randomX = Random.new():NextInteger(1, GRID_X)
			local randomY = Random.new():NextInteger(1, GRID_Y)
			if grid[randomX][randomY] == "Snake" then
				continue
			else
				grid[randomX][randomY] = "Apple"
				apple.Position = UDim2.fromScale(scaleX * (randomX - 1), scaleY * (randomY - 1))
				currentApple = { X = randomX, Y = randomY, Apple = apple }
				apple.Parent = gridSpace
				break
			end
		end
	end
	
	local function growSnake(length: number?)
		if length then
			for i = 1, length do
				growSnake()
			end
			return
		end
		
		local snakePart = Instance.new("Frame")
		snakePart.Name = "Snake"
		snakePart.ZIndex = 4
		snakePart.BackgroundColor3 = Color3.fromRGB(68, 255, 47)
		snakePart.Size = squareSize
		snakePart.BorderSizePixel = 0
		snakePart.Parent = gridSpace
		
		-- Spawn in the middle
		if #snake == 0 then
			local midX = math.round(GRID_X / 2)
			local midY = math.round(GRID_Y / 2)
			snakePart.Position = UDim2.fromScale(scaleX * (midX - 1), scaleY * (midY - 1))
			grid[midX][midY] = "Snake"
			table.insert(snake, { X = midX, Y = midY, Part = snakePart })
			return
		end
		
		-- Grow off the tail 1 square behind
		local tail = snake[#snake]
		local newX = tail.X - direction.X
		local newY = tail.Y - direction.Y
		grid[newX][newY] = "Snake"
		snakePart.Position = UDim2.fromScale(scaleX * (newX - 1), scaleY * (newY - 1))
		table.insert(snake, { X = newX, Y = newY, Part = snakePart })
	end
	
	local function eatApple()
		currentApples += 1
		apples.Text = `Apples: {currentApples}`
		sounds.eatSound:Play()
		if currentApples > currentHighScore then
			currentHighScore = currentApples
			highScore.Text = `High Score: {currentApples}`
		end
		
		spawnApple()
		growSnake()
	end
	
	local function moveSnakePart(snakePart: SnakePart, X: number, Y: number)
		grid[snakePart.X][snakePart.Y] = "Empty"
		snakePart.Part.Position = UDim2.fromScale(scaleX * (X - 1), scaleY * (Y - 1))
		snakePart.X = X
		snakePart.Y = Y
		grid[X][Y] = "Snake"
	end
	
	local function checkCollisions()
		local head = snake[1]
		local newX = head.X + direction.X
		local newY = head.Y + direction.Y
		-- Is in bounds
		if (newX > GRID_X or newX < 1) or (newY > GRID_Y or newY < 1) then
			return endGame(snake, conns)
		end
		
		local targetSquare = grid[newX][newY]
		if targetSquare == "Snake" then
			-- If the snake loops around and hits itself
			endGame(snake, conns)
		elseif targetSquare == "Apple" then
			eatApple()
		end
	end
	
	local function move() 
		checkCollisions()
		local newPositions = {}
		-- Save down new positions
		for i, snakePart in snake do
			-- If it's the head, shift it with its direction
			if i == 1 then
				local x = snakePart.X + direction.X
				local y = snakePart.Y + direction.Y
				table.insert(newPositions, { X = x, Y = y })
				continue
			end
			
			-- Shift to the position infront
			local target = snake[i - 1]
			table.insert(newPositions, { X = target.X, Y = target.Y })
		end
		
		-- Apply new positions
		for i, snakePart in snake do
			local newPosition = newPositions[i]
			moveSnakePart(snakePart, newPosition.X, newPosition.Y)
		end
	end
	
	-- Change direction
	table.insert(conns, UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		-- Arrows keys trigger the gameProcessedEvent so we have to make an exception
		local isArrow = input.KeyCode == Enum.KeyCode.Up
			or input.KeyCode == Enum.KeyCode.Down
			or input.KeyCode == Enum.KeyCode.Left
			or input.KeyCode == Enum.KeyCode.Right

		if gameProcessedEvent and not isArrow then
			return
		end
		
		if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.Up then
			-- We check the negative direction to prevent the snake from reversing
			if direction.Y ~= 1 then direction = { X = 0, Y = -1 } end
		elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			if direction.X ~= 1 then direction = { X = -1, Y = 0 } end
		elseif input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.Down then
			if direction.Y ~= -1 then direction = { X = 0, Y = 1 } end
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			if direction.X ~= -1 then direction = { X = 1, Y = 0 } end
		end
	end))
	
	growSnake(START_LENGTH)
	spawnApple()
	while playing do
		move()
		task.wait(SHIFT_TIME)
	end
end

local function playGame()
	if playing then
		return
	end
	playing = true
	loseScreen.Visible = false
	apples.Visible = true
	highScore.Visible = true

	local function endGame(snake: Snake, conns: { RBXScriptConnection })
		-- Lose screen
		loseScreen.Visible = true
		loseApples.Text = `Apples: {currentApples}`
		loseHighScore.Text = `High Score: {currentHighScore}`
		
		playing = false
		currentApples = 0
		play.Text = "Play"
		apples.Text = "Apples: 0"
		loseScreen.Visible = true
		apples.Visible = false
		highScore.Visible = false

		-- Clean up
		for _, conn in conns do
			conn:Disconnect()
		end

		if currentApple then
			currentApple.Apple:Destroy()
		end

		for _, snakePart in snake do
			snakePart.Part:Destroy()
		end
	end
	task.defer(startGame, endGame)
end

preloadAssets()
make2DGrid()

play.Activated:Connect(playGame)
restart.Activated:Connect(playGame)
