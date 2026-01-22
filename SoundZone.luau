-- Services
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local ZonePlus = require(ReplicatedStorage.Zone)

-- Constants
local Music = script.Parent.Music -- Music FOLDER
local EASE_OUT_TIME = 2

local SoundZone = {}
SoundZone.__index = SoundZone

function SoundZone.new(ZonePart: BasePart, TagName: string)
    local self = setmetatable({}, SoundZone)
    self._tagName = TagName
    self._zone = ZonePlus.new(ZonePart)
    self._enteredConnection = nil
    self._exitConnection = nil
    self.currentSound = nil

    self:enable()

    return self
end

function SoundZone:enable()
    -- do not create a new connection if the zone is already enabled.
    if self._enteredConnection then
        return
    end

    self._enteredConnection = self._zone.playerEntered:Connect(function()
        -- Music randomization
        while task.wait() do
            local playlist = Music[self._tagName]:GetChildren()
            local randomIndex = math.random(1, #playlist)
            self.currentSound = playlist[randomIndex] :: Sound
            self.currentSound:Play()
            self.currentSound.Ended:Wait()
        end
    end)

    self._exitConnection = self._zone.playerExited:Connect(function()
        self:disable() -- cancels the while loop by disconnecting the connection.
        local originalVolume = self.currentSound.Volume

        -- tween
        local completedConnection
        local tween = TweenService:Create(self.currentSound, TweenInfo.new(EASE_OUT_TIME), {
            Volume = 0,
        })
        tween:Play()
        completedConnection = tween.Completed:Connect(function()
            completedConnection:Disconnect()
            self.currentSound:Stop()
            self.currentSound.Volume = originalVolume
        end)

        self:enable() -- reenable it so it kind of "reboots"
    end)
end

function SoundZone:disable()
    if self._enteredConnection then
        self._enteredConnection:Disconnect()
        self._enteredConnection = nil
    end

    if self._exitConnection then
        self._exitConnection:Disconnect()
        self._exitConnection = nil
    end
end

return SoundZone
