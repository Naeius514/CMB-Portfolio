export type DojutsuType = "Sharingan" | "Byakugan" | "Rinnegan" | "MangekyouSharingan"

export type MonocularDojutsu = {
	type: "monocular",
	data: {
		hemiface: "left" | "right", -- which side of face does the eye appear on
		type: DojutsuType,
		progression: number,
	},
}

export type BinocularDojutsu = {
	type: "binocular",
	data: {
		type: DojutsuType,
		progression: number,
	},
}

export type SharinganClient = {
	name: DojutsuType,
	vision: ColorCorrectionEffect,
	state: boolean, -- Whether the dojutsu is on/off
	toggle: () -> nil,
}
return {}
