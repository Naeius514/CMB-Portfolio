--[=[
	run-tests.server.luau

	Use Roblox Jest to start the test suite.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jest = require(ReplicatedStorage.Packages.Jest)

local status, result = Jest.runCLI(ServerScriptService.Tests, { verbose = true }, { ServerScriptService.Tests })
	:awaitStatus()

if status == "Resolved" and result.results.numFailedTestSuites == 0 and result.results.numFailedTests == 0 then
	return "All tests passed"
end

error("Tests failed: " .. tostring(status))
