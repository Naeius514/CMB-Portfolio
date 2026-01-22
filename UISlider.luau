local function Slider(props: Props<string> & ItemProps, hooks: RoactHooks.Hooks)
	local isSliding, setIsSliding = hooks.useState(false)
	local guiObject, setGuiObject = hooks.useState(nil)
	local sliderValue, setSliderValue = hooks.useState(0)
	local sliderValueRef = hooks.useValue(sliderValue)

	hooks.useEffect(function()
		sliderValueRef.current = sliderValue
		props.Update(sliderValue)
	end, {sliderValue})

	hooks.useEffect(function()
		if isSliding then
			local function onInputEnded(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					setIsSliding(false)
					-- Access the latest slider value from the ref
					print("Slider Value on MouseButton1Up:", sliderValueRef.current)
				end
			end

			local Connection = UserInputService.InputEnded:Connect(onInputEnded)

			return function()
				if Connection then
					Connection:Disconnect()
					Connection = nil
				end
			end
		end
		
	end, {
		isSliding
	})

	hooks.useEffect(function()
		if isSliding and guiObject then
			local connection = RunService.RenderStepped:Connect(function()
				local MouseLocation = UserInputService:GetMouseLocation()
				local GetPosition = math.clamp(
					((Vector2.new(MouseLocation.X, MouseLocation.Y) - guiObject.Parent.AbsolutePosition)
							/ guiObject.Parent.AbsoluteSize).X, 0, 1)
				guiObject.Position = UDim2.fromScale(GetPosition, 0.5)
				setSliderValue(GetPosition)
			end)

			return function()
				connection:Disconnect()
			end
		end
	end, {isSliding, guiObject})
	
	return Roact.createElement('Frame', {
		Size = UDim2.new(1, 0, 0, props.titleSize.Y + SETTING_NAME_PADDING),
		BackgroundTransparency = 1,
	}, {
		Text = Roact.createElement(TextLabel, {
			LayoutOrder = 1,
			Size = UDim2.new(1, -(KEY_SELECT_SIZE + SETTING_NAME_PADDING), 1, 0),
			Text = props.Name,
			AutomaticSize = Enum.AutomaticSize.None,
			Font = Enum.Font.GothamMedium,
			TextSize = SETTING_NAME_TEXT_SIZE,
		}),
		
		Slider = Roact.createElement(Holder, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(0.79, 0, 0.5, 0),
			Size = UDim2.fromOffset(88, 5),
			Color = Constants.COLOURS.OFF_WHITE
		}, {
			Button = Roact.createElement('TextButton', {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = Constants.COLOURS.LIGHT_GREY,
				Text = '',
				[Roact.Event.MouseButton1Down] = function(GuiObject)
					setIsSliding(true)
					setGuiObject(GuiObject)
				end,
			}, {
				Roact.createElement('UICorner')
			})
		}),
		
		TextBox = Roact.createElement(Holder, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(37, 30),
			Color = Constants.COLOURS.OFF_WHITE
		}, {
			Roact.createElement('TextBox', {
				Position = UDim2.fromScale(0 ,0),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 20,
				Text = if math.floor((sliderValueRef.current or 0) * 100) == 0 then '1' else math.floor((sliderValueRef.current or 1) * 100),
				[Roact.Event.FocusLost] = function(TextBox)
					if TextBox.Text then
						setSliderValue(tonumber(TextBox.Text) / 100)
						TextBox.Parent.Parent.Slider.Button.Position = UDim2.fromScale(sliderValueRef.current, 0.5)
					end
				end,
				
				[Roact.Change.Text] = function(TextBox)
					local Value = tonumber(TextBox.Text)
					TextBox.Text = string.sub(TextBox.Text:gsub('%D+', ''), 1, 3)
					if TextBox.IsFocused and Value then
						if Value > 100 then
							TextBox.Text = 100
						end
					end
				end,
				
				[Roact.Event.Focused] = function(TextBox)
					TextBox.Text = ''
				end,
			})
			
		}),
	})
end
