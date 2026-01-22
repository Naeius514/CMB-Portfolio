local LookYaw = math.atan2(
    RootPart.CFrame.LookVector.Z,
    RootPart.CFrame.LookVector.X
)

local RightDot = RootPart.CFrame.RightVector:Dot(Camera.CFrame.LookVector)
local ForwardDot = RootPart.CFrame.LookVector:Dot(Camera.CFrame.LookVector)
local Settings = require(Vehicle.CarSettings)

-- CAMERA 
Camera.CFrame *= CFrame.new(
    math.min(0, ForwardDot * (-VehicleSide * 10)),
    math.sqrt(math.pow(RightDot, 2) + 0.005) * Settings.CameraHeightWhenAimingOverCar,
    0
)

VehicularAiming:FireServer({
    ForwardDot = ForwardDot,
    RightDot = RightDot,
    LookYaw = LookYaw,
    CameraAngle = self.CameraAngleX
})

self.Character.LowerTorso.Root.C0 = 
    CFrame.new( -- POSITIONING 
        (-VehicleSide * Settings.DefaultDistanceFromDoor) + 
        (VehicleSide * (RightDot * Settings.AdditionalDistanceFromDoorWhenAimingOverCar)),
        -1 + math.max(0, VehicleSide * (RightDot * Settings.HeightWhenAimingOverCar)),
        0
    ) 
    * CFrame.Angles( -- ROTATION
        0,
        (self.CameraAngleX + LookYaw) + math.pi / 2,
        math.rad(
            (VehicleSide * ForwardDot * Settings.BodyTiltTowardsWindow) + 
            (1 - (VehicleSide * ForwardDot * Settings.BodyTiltTowardsWindow)) * 
            math.clamp((VehicleSide * RightDot), 0, 1)
        )
    )
