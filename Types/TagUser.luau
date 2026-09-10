export type Injury = "CUT" | "SMOKE INHALATION"

export type CuresChecklist = { [string]: boolean }
-- Individual injuries have their own checklist. Once everything in the checklist is TRUE, the Injury will go away.

export type Symptom = "COUGH" | "BLEEDOUT"

export type DPS = { DamagePerSecondRate: number }
export type TagUser = {
	Tag: (TagList: TagList) -> nil,
	Damage: (Amount: number) -> number,
	DamagePerSecond: (Settings: DPS) -> nil,
	InflictInjury: (Injury: Injury) -> nil,
	Knock: () -> nil,
	Grip: () -> nil,
}

export type TagList = {
	Damage: number,
}

return {}
