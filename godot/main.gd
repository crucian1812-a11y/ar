extends Node3D
# ═══════════════════════════════════════════════════════════════
#  BJJ Godot Arena — бразильское джиу-джитсу, борьба на ковре.
#  Порт веб-версии: раунды, очки IBJJF, QTE, тап-баттлы, ИИ.
# ═══════════════════════════════════════════════════════════════

# ── сложность ──
const DIFFS := [
	{"name": "БЕЛЫЙ ПОЯС", "belt": Color("f5f5f5"), "hair": "brown",
	 "ai_min": 6.0, "ai_max": 9.0, "ai_chance": 0.70, "zone": 0.34, "speed": 0.90,
	 "drain": 14.0, "tap": 6.0, "def_start": 55.0, "atk_start": 55.0, "ai_regen": 2.2},
	{"name": "ПУРПУРНЫЙ ПОЯС", "belt": Color("8e44ad"), "hair": "blond",
	 "ai_min": 4.5, "ai_max": 7.0, "ai_chance": 1.00, "zone": 0.26, "speed": 1.15,
	 "drain": 20.0, "tap": 5.0, "def_start": 48.0, "atk_start": 50.0, "ai_regen": 3.0},
	{"name": "ЧЁРНЫЙ ПОЯС", "belt": Color("141414"), "hair": "bald",
	 "ai_min": 3.0, "ai_max": 5.0, "ai_chance": 1.30, "zone": 0.19, "speed": 1.40,
	 "drain": 27.0, "tap": 4.2, "def_start": 40.0, "atk_start": 45.0, "ai_regen": 3.8},
]

const POSITIONS := {
	"standing":     {"label": "Стойка", "side": "нейтрально"},
	"guard_top":    {"label": "Гвард соперника", "side": "вы сверху"},
	"guard_bottom": {"label": "Ваш гвард", "side": "вы снизу"},
	"side_top":     {"label": "Боковой контроль", "side": "вы сверху"},
	"side_bottom":  {"label": "Боковой контроль", "side": "вы снизу"},
	"mount_top":    {"label": "Маунт", "side": "вы сверху"},
	"mount_bottom": {"label": "Маунт соперника", "side": "вы снизу"},
	"back_top":     {"label": "Спина взята!", "side": "вы контролируете"},
	"back_bottom":  {"label": "Соперник на спине", "side": "опасно!"},
}

const PLAYER_ACTIONS := {
	"standing": [
		{"id": "td", "name": "Тейкдаун", "hint": "проход в ноги · +2", "chance": 0.60, "cost": 18.0, "pts": 2, "to": "guard_top"},
		{"id": "pull", "name": "Затянуть в гвард", "hint": "без очков", "chance": 0.92, "cost": 8.0, "pts": 0, "to": "guard_bottom"},
	],
	"guard_top": [
		{"id": "passK", "name": "Проход через колено", "hint": "+3", "chance": 0.55, "cost": 18.0, "pts": 3, "to": "side_top"},
		{"id": "passS", "name": "Стек-проход", "hint": "мощно · +3", "chance": 0.45, "cost": 24.0, "pts": 3, "to": "side_top"},
	],
	"guard_bottom": [
		{"id": "sweepS", "name": "Свип-ножницы", "hint": "+2, вы сверху", "chance": 0.55, "cost": 18.0, "pts": 2, "to": "guard_top"},
		{"id": "sweepF", "name": "Флауэр-свип", "hint": "риск · +2 и маунт!", "chance": 0.38, "cost": 24.0, "pts": 2, "to": "mount_top"},
		{"id": "tri", "name": "Треугольник", "hint": "удушающий", "chance": 0.48, "cost": 22.0, "sub": "треугольником", "cls": "sub"},
		{"id": "arm", "name": "Армбар", "hint": "болевой на руку", "chance": 0.44, "cost": 22.0, "sub": "армбаром", "cls": "sub"},
	],
	"side_top": [
		{"id": "mnt", "name": "Выход в маунт", "hint": "+4", "chance": 0.55, "cost": 18.0, "pts": 4, "to": "mount_top"},
		{"id": "kim", "name": "Кимура", "hint": "болевой на плечо", "chance": 0.48, "cost": 20.0, "sub": "кимурой", "cls": "sub"},
	],
	"side_bottom": [
		{"id": "rec", "name": "Вернуть гвард", "hint": "закрыть ноги", "chance": 0.60, "cost": 15.0, "pts": 0, "to": "guard_bottom"},
		{"id": "brg", "name": "Мост и выход", "hint": "в стойку", "chance": 0.42, "cost": 20.0, "pts": 0, "to": "standing"},
	],
	"mount_top": [
		{"id": "armM", "name": "Армбар", "hint": "болевой", "chance": 0.52, "cost": 20.0, "sub": "армбаром", "cls": "sub"},
		{"id": "chk", "name": "Крест", "hint": "удушающий воротом", "chance": 0.48, "cost": 20.0, "sub": "удушением", "cls": "sub"},
		{"id": "back", "name": "Забрать спину", "hint": "+4", "chance": 0.48, "cost": 15.0, "pts": 4, "to": "back_top"},
	],
	"mount_bottom": [
		{"id": "upa", "name": "Упа (переворот)", "hint": "мост — вы сверху!", "chance": 0.48, "cost": 22.0, "pts": 0, "to": "guard_top"},
		{"id": "elb", "name": "Локти-колени", "hint": "вернуть гвард", "chance": 0.58, "cost": 15.0, "pts": 0, "to": "guard_bottom"},
	],
	"back_top": [
		{"id": "rnc", "name": "Мата-леон", "hint": "удушающий сзади", "chance": 0.58, "cost": 20.0, "sub": "мата-леоном", "cls": "sub"},
		{"id": "hold", "name": "Держать крюки", "hint": "+выносливость", "chance": 1.0, "cost": 0.0, "restore": 22.0, "cls": "rest"},
	],
	"back_bottom": [
		{"id": "strip", "name": "Снять крюки", "hint": "уйти в гвард", "chance": 0.48, "cost": 18.0, "pts": 0, "to": "guard_bottom"},
		{"id": "wall", "name": "Защита шеи", "hint": "+выносливость", "chance": 1.0, "cost": 0.0, "restore": 16.0, "cls": "rest"},
	],
}

const AI_ACTIONS := {
	"standing": [
		{"w": 5.0, "name": "тейкдаун", "chance": 0.42, "pts": 2, "to": "guard_bottom", "msg": "Соперник прошёл в ноги — тейкдаун!"},
		{"w": 2.0, "name": "затягивание", "chance": 0.80, "pts": 0, "to": "guard_top", "msg": "Соперник затянул вас в свой гвард."},
	],
	"guard_top": [
		{"w": 4.0, "name": "свип", "chance": 0.40, "pts": 2, "to": "guard_bottom", "msg": "Соперник сделал свип — вы снизу!"},
		{"w": 3.0, "name": "треугольник", "chance": 0.38, "sub": "треугольник", "msg": "Соперник ловит треугольник!"},
	],
	"guard_bottom": [
		{"w": 5.0, "name": "проход гварда", "chance": 0.42, "pts": 3, "to": "side_bottom", "msg": "Соперник прошёл ваш гвард! +3"},
	],
	"side_top": [
		{"w": 4.0, "name": "возврат гварда", "chance": 0.45, "pts": 0, "to": "guard_top", "msg": "Соперник вернул гвард."},
		{"w": 2.0, "name": "уход в стойку", "chance": 0.35, "pts": 0, "to": "standing", "msg": "Соперник вскочил в стойку."},
	],
	"side_bottom": [
		{"w": 4.0, "name": "выход в маунт", "chance": 0.40, "pts": 4, "to": "mount_bottom", "msg": "Соперник вышел в маунт! +4"},
		{"w": 3.0, "name": "кимура", "chance": 0.36, "sub": "кимуру", "msg": "Соперник крутит кимуру!"},
	],
	"mount_top": [
		{"w": 4.0, "name": "упа", "chance": 0.40, "pts": 0, "to": "guard_bottom", "msg": "Соперник перевернул вас мостом!"},
		{"w": 3.0, "name": "локти-колени", "chance": 0.45, "pts": 0, "to": "guard_top", "msg": "Соперник вернул гвард."},
	],
	"mount_bottom": [
		{"w": 4.0, "name": "армбар", "chance": 0.42, "sub": "армбар", "msg": "Соперник выходит на армбар!"},
		{"w": 4.0, "name": "удушение", "chance": 0.42, "sub": "удушение", "msg": "Соперник давит удушающий!"},
	],
	"back_top": [
		{"w": 4.0, "name": "выход со спины", "chance": 0.38, "pts": 0, "to": "side_top", "msg": "Соперник слез со спины, вы удержали верх."},
	],
	"back_bottom": [
		{"w": 5.0, "name": "мата-леон", "chance": 0.50, "sub": "мата-леон", "msg": "Соперник затягивает мата-леон!!"},
	],
}

# ── позы (эйлеры суставов, радианы) ──
const P_STAND := {"spine": Vector3(0.35, 0, 0), "neck": Vector3(-0.28, 0, 0),
	"shL": Vector3(-1.1, 0, -0.18), "shR": Vector3(-1.1, 0, 0.18),
	"elL": Vector3(-0.65, 0, 0), "elR": Vector3(-0.65, 0, 0),
	"hipL": Vector3(-0.35, 0, -0.08), "hipR": Vector3(-0.35, 0, 0.08),
	"kneeL": Vector3(0.65, 0, 0), "kneeR": Vector3(0.65, 0, 0)}
const P_KNEEL := {"spine": Vector3(0.5, 0, 0), "neck": Vector3(-0.4, 0, 0),
	"shL": Vector3(-1.25, 0, -0.25), "shR": Vector3(-1.25, 0, 0.25),
	"elL": Vector3(-0.45, 0, 0), "elR": Vector3(-0.45, 0, 0),
	"hipL": Vector3(-0.55, 0, -0.3), "hipR": Vector3(-0.55, 0, 0.3),
	"kneeL": Vector3(1.9, 0, 0), "kneeR": Vector3(1.9, 0, 0)}
const P_GUARD_BTM := {"spine": Vector3(0.3, 0, 0), "neck": Vector3(0.45, 0, 0),
	"shL": Vector3(-1.35, 0, -0.35), "shR": Vector3(-1.35, 0, 0.35),
	"elL": Vector3(-0.55, 0, 0), "elR": Vector3(-0.55, 0, 0),
	"hipL": Vector3(-1.5, 0, -0.55), "hipR": Vector3(-1.5, 0, 0.55),
	"kneeL": Vector3(1.35, 0, 0), "kneeR": Vector3(1.35, 0, 0)}
const P_LIE_FLAT := {"spine": Vector3(0.12, 0, 0), "neck": Vector3(0.3, 0, 0),
	"shL": Vector3(-1.2, 0, -0.45), "shR": Vector3(-1.2, 0, 0.45),
	"elL": Vector3(-0.95, 0, 0), "elR": Vector3(-0.95, 0, 0),
	"hipL": Vector3(-0.3, 0, -0.18), "hipR": Vector3(-0.3, 0, 0.18),
	"kneeL": Vector3(0.55, 0, 0), "kneeR": Vector3(0.55, 0, 0)}
const P_LIE_DEFEND := {"spine": Vector3(0.18, 0, 0), "neck": Vector3(0.4, 0, 0),
	"shL": Vector3(-1.5, 0, -0.2), "shR": Vector3(-1.5, 0, 0.2),
	"elL": Vector3(-1.35, 0, 0), "elR": Vector3(-1.35, 0, 0),
	"hipL": Vector3(-0.45, 0, -0.2), "hipR": Vector3(-0.45, 0, 0.2),
	"kneeL": Vector3(0.8, 0, 0), "kneeR": Vector3(0.8, 0, 0)}
const P_SIDE_TOP := {"spine": Vector3(0.95, 0, 0), "neck": Vector3(-0.65, 0, 0),
	"shL": Vector3(-1.5, 0, -0.5), "shR": Vector3(-1.5, 0, 0.5),
	"elL": Vector3(-0.95, 0, 0), "elR": Vector3(-0.95, 0, 0),
	"hipL": Vector3(-0.7, 0, -0.3), "hipR": Vector3(-0.7, 0, 0.3),
	"kneeL": Vector3(1.7, 0, 0), "kneeR": Vector3(1.7, 0, 0)}
const P_MOUNT_TOP := {"spine": Vector3(0.28, 0, 0), "neck": Vector3(-0.25, 0, 0),
	"shL": Vector3(-1.0, 0, -0.3), "shR": Vector3(-1.0, 0, 0.3),
	"elL": Vector3(-0.75, 0, 0), "elR": Vector3(-0.75, 0, 0),
	"hipL": Vector3(-1.1, 0, -0.85), "hipR": Vector3(-1.1, 0, 0.85),
	"kneeL": Vector3(1.65, 0, 0), "kneeR": Vector3(1.65, 0, 0)}
const P_BACK_TOP := {"spine": Vector3(0.4, 0, 0), "neck": Vector3(0.15, 0, 0),
	"shL": Vector3(-1.5, 0, -0.35), "shR": Vector3(-1.5, 0, 0.35),
	"elL": Vector3(-1.4, 0, 0), "elR": Vector3(-1.4, 0, 0),
	"hipL": Vector3(-1.2, 0, -0.8), "hipR": Vector3(-1.2, 0, 0.8),
	"kneeL": Vector3(1.55, 0, 0), "kneeR": Vector3(1.55, 0, 0)}
const P_BACK_SEAT := {"spine": Vector3(0.2, 0, 0), "neck": Vector3(0.1, 0, 0),
	"shL": Vector3(-1.55, 0, -0.12), "shR": Vector3(-1.55, 0, 0.12),
	"elL": Vector3(-1.5, 0, 0), "elR": Vector3(-1.5, 0, 0),
	"hipL": Vector3(-0.65, 0, -0.22), "hipR": Vector3(-0.65, 0, 0.22),
	"kneeL": Vector3(2.0, 0, 0), "kneeR": Vector3(2.0, 0, 0)}

var SCENES := {}

# ── состояние игры ──
var screen := "menu"      # menu | fight | qte | struggle | rest | end
var diff := 0
var total_rounds := 3
var round_time := 90.0
var round_no := 1
var clock := 90.0
var pos := "standing"
var pts_you := 0
var pts_foe := 0
var adv_you := 0
var adv_foe := 0
var stam_you := 100.0
var stam_foe := 100.0
var def_until := 0.0
var def_cooldown := 0.0
var ai_timer := 5.0
var game_time := 0.0
var qte := {}             # action,t,dir,speed,zone_start,zone_w
var st := {}              # mode,fill,time_left,sub_name
var cam_angle := 0.7
var cam_dist := 3.1
var cam_height := 1.75
var cam_shake := 0.0
var flash_alpha := 0.0
var flash_color := Color(0, 0, 0)

# ── 3D ──
var cam: Camera3D
var you: Dictionary = {}
var foe: Dictionary = {}
var wobble := {}

# ── UI ──
var ui: CanvasLayer
var lbl_pts_you: Label
var lbl_pts_foe: Label
var lbl_adv_you: Label
var lbl_adv_foe: Label
var lbl_clock: Label
var lbl_round: Label
var lbl_foe_name: Label
var lbl_pos: Label
var lbl_pos_side: Label
var lbl_log: Label
var bar_you: ColorRect
var bar_foe: ColorRect
var flash_rect: ColorRect
var actions_grid: GridContainer
var action_buttons := []       # [{btn, act, is_def}]
var rendered_pos := ""
var ov_menu: Control
var ov_qte: Control
var ov_st: Control
var ov_rest: Control
var ov_end: Control
var qte_name_lbl: Label
var qte_zone: ColorRect
var qte_mark: ColorRect
var qte_track: ColorRect
var st_name_lbl: Label
var st_sub_lbl: Label
var st_fill: ColorRect
var st_timer_lbl: Label
var st_btn: Button
var rest_title: Label
var rest_detail: Label
var end_title: Label
var end_detail: Label
var menu_chip_rows := {}       # key -> [buttons]
var crowd_planes := []


func _ready() -> void:
	_build_scenes_table()
	_build_environment()
	_build_arena()
	you = _make_fighter(Color("2455b4"), Color("193e85"), Color("db9c63"), Color("17181d"), "brown", false)
	_spawn_foe()
	_build_wobble()
	_build_ui()
	_show_only("menu")


func _build_scenes_table() -> void:
	SCENES = {
		"standing": {
			"you": {"p": Vector3(0, 0.80, 0.62), "yaw": PI, "pitch": 0.0, "j": P_STAND},
			"foe": {"p": Vector3(0, 0.80, -0.62), "yaw": 0.0, "pitch": 0.0, "j": P_STAND}},
		"guard_top": {
			"foe": {"p": Vector3(0, 0.15, -0.12), "yaw": 0.0, "pitch": -PI / 2, "j": P_GUARD_BTM},
			"you": {"p": Vector3(0, 0.46, 0.46), "yaw": PI, "pitch": 0.0, "j": P_KNEEL}},
		"guard_bottom": {
			"you": {"p": Vector3(0, 0.15, 0.12), "yaw": PI, "pitch": -PI / 2, "j": P_GUARD_BTM},
			"foe": {"p": Vector3(0, 0.46, -0.46), "yaw": 0.0, "pitch": 0.0, "j": P_KNEEL}},
		"side_top": {
			"foe": {"p": Vector3(0, 0.15, -0.05), "yaw": 0.0, "pitch": -PI / 2, "j": P_LIE_FLAT},
			"you": {"p": Vector3(0.34, 0.44, -0.30), "yaw": -PI / 2, "pitch": 0.0, "j": P_SIDE_TOP}},
		"side_bottom": {
			"you": {"p": Vector3(0, 0.15, 0.05), "yaw": PI, "pitch": -PI / 2, "j": P_LIE_FLAT},
			"foe": {"p": Vector3(0.34, 0.44, 0.30), "yaw": -PI / 2, "pitch": 0.0, "j": P_SIDE_TOP}},
		"mount_top": {
			"foe": {"p": Vector3(0, 0.15, -0.05), "yaw": 0.0, "pitch": -PI / 2, "j": P_LIE_DEFEND},
			"you": {"p": Vector3(0, 0.56, -0.30), "yaw": PI, "pitch": 0.0, "j": P_MOUNT_TOP}},
		"mount_bottom": {
			"you": {"p": Vector3(0, 0.15, 0.05), "yaw": PI, "pitch": -PI / 2, "j": P_LIE_DEFEND},
			"foe": {"p": Vector3(0, 0.56, 0.30), "yaw": 0.0, "pitch": 0.0, "j": P_MOUNT_TOP}},
		"back_top": {
			"foe": {"p": Vector3(0, 0.50, 0.08), "yaw": 0.0, "pitch": 0.0, "j": P_BACK_SEAT},
			"you": {"p": Vector3(0, 0.60, -0.26), "yaw": 0.0, "pitch": 0.25, "j": P_BACK_TOP}},
		"back_bottom": {
			"you": {"p": Vector3(0, 0.50, -0.08), "yaw": PI, "pitch": 0.0, "j": P_BACK_SEAT},
			"foe": {"p": Vector3(0, 0.60, 0.26), "yaw": PI, "pitch": 0.25, "j": P_BACK_TOP}},
	}


# ═══════════════════════ ОКРУЖЕНИЕ ═══════════════════════
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("05060b")
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_light_color = Color("05060b")
	env.fog_density = 0.028
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("30354a")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := SpotLight3D.new()
	key.position = Vector3(2.2, 6.5, 1.6)
	key.spot_range = 30.0
	key.spot_angle = 38.0
	key.light_energy = 5.0
	key.light_color = Color("fff0d8")
	key.shadow_enabled = true
	add_child(key)
	key.look_at(Vector3.ZERO)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-3.5, 3.4, -2.5)
	fill.omni_range = 14.0
	fill.light_energy = 1.1
	fill.light_color = Color("7fa0ff")
	add_child(fill)

	var rim := OmniLight3D.new()
	rim.position = Vector3(3, 2.6, -3.2)
	rim.omni_range = 12.0
	rim.light_energy = 1.0
	rim.light_color = Color("ff9a55")
	add_child(rim)

	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.position = Vector3(2.2, 1.8, 2.2)
	cam.look_at(Vector3(0, 0.45, 0))


func _mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _emissive(c: Color, energy := 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _box(size: Vector3, mat: Material, p: Vector3, parent: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = p
	parent.add_child(mi)
	return mi


func _sphere(r: float, mat: Material, p: Vector3, parent: Node3D) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = p
	parent.add_child(mi)
	return mi


func _cyl(rt: float, rb: float, h: float, mat: Material, p: Vector3, parent: Node3D) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = rt
	mesh.bottom_radius = rb
	mesh.height = h
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = p
	parent.add_child(mi)
	return mi


func _crowd_texture() -> ImageTexture:
	var img := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color("0a0c14"))
	var skins := [Color("e0ac69"), Color("c68642"), Color("8d5524"), Color("f1c27d")]
	var cloth := [Color("31405f"), Color("5c2f3a"), Color("2d4a38"), Color("4a4458"), Color("613f23")]
	for row in range(6):
		var y := 120 - row * 20
		var sz := 7 - row
		var x := 4
		while x < 250:
			var cc: Color = cloth[randi() % cloth.size()]
			var sc: Color = skins[randi() % skins.size()]
			var dim := 1.0 - row * 0.1
			for dx in range(sz):
				for dy in range(sz):
					var px := x + dx
					var py := y - 3 + dy
					if px < 256 and py >= 0 and py < 128:
						img.set_pixel(px, py, cc * dim)
			for dx in range(sz - 2):
				for dy in range(sz - 2):
					var px2 := x + 1 + dx
					var py2 := y - sz + dy
					if px2 < 256 and py2 >= 0 and py2 < 128:
						img.set_pixel(px2, py2, sc * dim)
			x += sz + 2 + randi() % 4
	return ImageTexture.create_from_image(img)


func _build_arena() -> void:
	# чёрный глянцевый пол
	_box(Vector3(30, 0.1, 30), _mat(Color("0a0c12"), 0.3, 0.5), Vector3(0, -0.31, 0), self)
	# подиум
	_box(Vector3(7.4, 0.26, 7.4), _mat(Color("14161f"), 0.6, 0.2), Vector3(0, -0.13, 0), self)
	# LED-борта подиума
	for d in [[0.0, 3.72, 0.0], [0.0, -3.72, 0.0], [3.72, 0.0, PI / 2], [-3.72, 0.0, PI / 2]]:
		var led := _box(Vector3(7.4, 0.2, 0.03), _emissive(Color("1c66c9"), 2.2), Vector3(d[0], -0.13, d[1]), self)
		led.rotation.y = d[2]
	# соревновательный мат: жёлтый центр + красная кайма
	_box(Vector3(7, 0.02, 7), _mat(Color("caa63c"), 0.92), Vector3(0, 0.0, 0), self)
	_box(Vector3(4.9, 0.022, 4.9), _mat(Color("a8362e"), 0.92), Vector3(0, 0.001, 0), self)
	_box(Vector3(3.6, 0.024, 3.6), _mat(Color("caa63c"), 0.92), Vector3(0, 0.002, 0), self)
	# трибуны с толпой
	for d in [[0.0, -11.0, 0.0], [0.0, 11.0, PI], [-11.0, 0.0, PI / 2], [11.0, 0.0, -PI / 2]]:
		var quad := QuadMesh.new()
		quad.size = Vector2(22, 7)
		var m := StandardMaterial3D.new()
		m.albedo_texture = _crowd_texture()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		quad.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.position = Vector3(d[0], 2.8, d[1])
		mi.rotation.y = d[2]
		add_child(mi)
		crowd_planes.append(mi)
	# световые конусы
	for cpos in [Vector3(-1.9, 3.1, -1.9), Vector3(1.9, 3.1, -1.9), Vector3(-1.9, 3.1, 1.9), Vector3(1.9, 3.1, 1.9)]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.15
		cone.bottom_radius = 1.5
		cone.height = 6.2
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color(1.0, 0.95, 0.85, 0.045)
		cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		cone.material = cm
		var mi2 := MeshInstance3D.new()
		mi2.mesh = cone
		mi2.position = cpos
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi2)


# ═══════════════════════ БОЕЦ В КИМОНО ═══════════════════════
func _make_fighter(gi_c: Color, edge_c: Color, skin_c: Color, belt_c: Color, hair: String, beard: bool) -> Dictionary:
	var gi := _mat(gi_c, 0.88)
	var edge := _mat(edge_c, 0.85)
	var skin := _mat(skin_c, 0.55)
	var beltm := _mat(belt_c, 0.8)
	var hair_c := Color("14100c")
	if hair == "blond":
		hair_c = Color("c9a227")
	elif hair == "brown":
		hair_c = Color("2e2018")
	var hairm := _mat(hair_c, 0.92)

	var root := Node3D.new()
	add_child(root)
	var F := {"root": root}

	# таз
	var seat := _sphere(0.145, gi, Vector3.ZERO, root)
	seat.scale = Vector3(1.12, 0.62, 0.85)

	# куртка (аппроксимация lathe набором цилиндров)
	var spine := Node3D.new()
	spine.position = Vector3(0, 0.13, 0)
	root.add_child(spine)
	F["spine"] = spine
	var skirt := _cyl(0.165, 0.185, 0.12, gi, Vector3(0, -0.10, 0), spine)
	skirt.scale = Vector3(1.16, 1, 0.80)
	var waist := _cyl(0.158, 0.166, 0.14, gi, Vector3(0, 0.03, 0), spine)
	waist.scale = Vector3(1.16, 1, 0.80)
	var chest := _cyl(0.150, 0.166, 0.18, gi, Vector3(0, 0.19, 0), spine)
	chest.scale = Vector3(1.16, 1, 0.80)
	var chest_top := _sphere(0.155, gi, Vector3(0, 0.29, 0), spine)
	chest_top.scale = Vector3(1.22, 0.72, 0.82)
	# V-ворот
	for s in [-1.0, 1.0]:
		var lap := _box(Vector3(0.055, 0.34, 0.02), edge, Vector3(s * 0.052, 0.20, 0.118), spine)
		lap.rotation.z = s * 0.30
		lap.rotation.x = -0.10
	var back_collar := _cyl(0.075, 0.082, 0.045, edge, Vector3(0, 0.365, -0.01), spine)
	back_collar.scale = Vector3(1.05, 1, 0.95)
	# пояс
	var belt := _cyl(0.172, 0.177, 0.055, beltm, Vector3(0, -0.045, 0), spine)
	belt.scale = Vector3(1.14, 1, 0.82)
	var knot := _sphere(0.045, beltm, Vector3(0, -0.045, 0.135), spine)
	knot.scale = Vector3(1.25, 0.8, 0.7)
	for s in [-1.0, 1.0]:
		var tail := _box(Vector3(0.042, 0.16, 0.016), beltm, Vector3(s * 0.04, -0.135, 0.135), spine)
		tail.rotation.z = s * 0.22

	# шея и голова
	var neck := Node3D.new()
	neck.position = Vector3(0, 0.40, 0)
	spine.add_child(neck)
	F["neck"] = neck
	_cyl(0.048, 0.06, 0.09, skin, Vector3(0, 0.02, 0), neck)
	var head := Node3D.new()
	head.position = Vector3(0, 0.15, 0)
	neck.add_child(head)
	var skull := _sphere(0.103, skin, Vector3.ZERO, head)
	skull.scale = Vector3(0.92, 1.04, 0.96)
	if hair != "bald":
		var hm := _sphere(0.104, hairm, Vector3(0, 0.022, -0.012), head)
		hm.scale = Vector3(0.9, 0.82, 0.95)
	if beard:
		var bm := _sphere(0.085, hairm, Vector3(0, -0.045, 0.03), head)
		bm.scale = Vector3(0.85, 0.62, 0.85)
	for s in [-1.0, 1.0]:
		_sphere(0.0155, _mat(Color("fbfbfb"), 0.35), Vector3(s * 0.036, 0.012, 0.085), head)
		_sphere(0.007, _mat(Color("241812"), 0.3), Vector3(s * 0.036, 0.012, 0.098), head)
		var brow := _box(Vector3(0.034, 0.0075, 0.011), hairm, Vector3(s * 0.036, 0.043, 0.090), head)
		brow.rotation.z = s * -0.12
		var ear := _sphere(0.021, skin, Vector3(s * 0.093, -0.002, 0), head)
		ear.scale = Vector3(0.5, 0.9, 0.75)
	var nose := _sphere(0.016, skin, Vector3(0, -0.012, 0.098), head)
	nose.scale = Vector3(0.85, 1.1, 1)
	_box(Vector3(0.038, 0.007, 0.008), _mat(Color("8a5a50"), 0.6), Vector3(0, -0.052, 0.086), head)

	# руки
	for sd in [["L", -1.0], ["R", 1.0]]:
		var side: String = sd[0]
		var sgn: float = sd[1]
		var sh := Node3D.new()
		sh.position = Vector3(sgn * 0.205, 0.30, 0)
		spine.add_child(sh)
		F["sh" + side] = sh
		_sphere(0.072, gi, Vector3.ZERO, sh)
		_cyl(0.060, 0.064, 0.20, gi, Vector3(0, -0.13, 0), sh)
		var el := Node3D.new()
		el.position = Vector3(0, -0.27, 0)
		sh.add_child(el)
		F["el" + side] = el
		_sphere(0.060, gi, Vector3.ZERO, el)
		_cyl(0.062, 0.066, 0.16, gi, Vector3(0, -0.10, 0), el)
		_cyl(0.067, 0.067, 0.035, edge, Vector3(0, -0.185, 0), el)
		var hand := _sphere(0.046, skin, Vector3(0, -0.235, 0), el)
		hand.scale = Vector3(0.82, 1.05, 0.9)
		var fingers := _sphere(0.040, skin, Vector3(0, -0.275, 0.012), el)
		fingers.scale = Vector3(0.95, 0.8, 1.0)

	# ноги
	for sd in [["L", -1.0], ["R", 1.0]]:
		var side2: String = sd[0]
		var sgn2: float = sd[1]
		var hip := Node3D.new()
		hip.position = Vector3(sgn2 * 0.10, -0.05, 0)
		root.add_child(hip)
		F["hip" + side2] = hip
		_sphere(0.082, gi, Vector3.ZERO, hip)
		_cyl(0.080, 0.084, 0.30, gi, Vector3(0, -0.185, 0), hip)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.38, 0)
		hip.add_child(knee)
		F["knee" + side2] = knee
		_sphere(0.075, gi, Vector3.ZERO, knee)
		_cyl(0.070, 0.075, 0.22, gi, Vector3(0, -0.14, 0), knee)
		_cyl(0.076, 0.076, 0.035, edge, Vector3(0, -0.255, 0), knee)
		_cyl(0.038, 0.042, 0.05, skin, Vector3(0, -0.29, 0), knee)
		var foot := _sphere(0.052, skin, Vector3(0, -0.325, 0.05), knee)
		foot.scale = Vector3(0.85, 0.55, 1.75)

	return F


func _spawn_foe() -> void:
	if foe.has("root"):
		foe["root"].queue_free()
	var d: Dictionary = DIFFS[diff]
	var skins := [Color("e8b077"), Color("c68642"), Color("8d5524")]
	foe = _make_fighter(Color("f1f1ea"), Color("d8d8ce"), skins[diff], d["belt"],
		d["hair"], d["hair"] == "bald")


func _build_wobble() -> void:
	wobble = {}
	for who in ["you", "foe"]:
		var w := {}
		for j in ["spine", "neck", "shL", "shR", "elL", "elR", "hipL", "hipR", "kneeL", "kneeR"]:
			w[j] = Vector3(randf_range(0, 6), randf_range(1.5, 2.6), randf_range(0, 6))
		wobble[who] = w


# ═══════════════════════ UI ═══════════════════════
func _lbl(text: String, size: int, c: Color, parent: Control, p: Vector2, w: float, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.position = p
	l.size = Vector2(w, size * 1.5)
	l.horizontal_alignment = align
	parent.add_child(l)
	return l


func _rect(c: Color, p: Vector2, s: Vector2, parent: Control) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.position = p
	r.size = s
	parent.add_child(r)
	return r


func _btn(text: String, size: int, parent: Control, p: Vector2, s: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.position = p
	b.size = s
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _overlay() -> Control:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.08, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(bg)
	ui.add_child(ov)
	return ov


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var base := Control.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(base)

	# табло
	_rect(Color("123a6e"), Vector2(16, 16), Vector2(250, 96), base)
	_rect(Color("3a3a42"), Vector2(454, 16), Vector2(250, 96), base)
	_rect(Color("080c14"), Vector2(280, 16), Vector2(160, 96), base)
	_lbl("ВЫ · СИНИЙ", 18, Color("cfe3ff"), base, Vector2(28, 22), 220, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_foe_name = _lbl("СОПЕРНИК", 18, Color("e0e0e0"), base, Vector2(462, 22), 234, HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_pts_you = _lbl("0", 44, Color.WHITE, base, Vector2(28, 44), 100, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_pts_foe = _lbl("0", 44, Color.WHITE, base, Vector2(596, 44), 100, HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_adv_you = _lbl("Преим.: 0", 14, Color("bcd2f0"), base, Vector2(130, 66), 130, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_adv_foe = _lbl("Преим.: 0", 14, Color("d5d5d5"), base, Vector2(462, 66), 130, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_clock = _lbl("1:30", 40, Color("ffd54a"), base, Vector2(280, 28), 160)
	lbl_round = _lbl("РАУНД 1/3", 15, Color("aab6cc"), base, Vector2(280, 80), 160)

	# стамина
	_rect(Color("1a2233"), Vector2(16, 122), Vector2(336, 14), base)
	_rect(Color("1a2233"), Vector2(368, 122), Vector2(336, 14), base)
	bar_you = _rect(Color("2f80ed"), Vector2(16, 122), Vector2(336, 14), base)
	bar_foe = _rect(Color("eb5757"), Vector2(368, 122), Vector2(336, 14), base)

	# позиция и лог
	lbl_pos = _lbl("Стойка", 24, Color.WHITE, base, Vector2(110, 150), 500)
	lbl_pos_side = _lbl("нейтрально", 15, Color("aab6cc"), base, Vector2(110, 184), 500)
	lbl_log = _lbl("", 18, Color("cfe3ff"), base, Vector2(20, 838), 680)
	lbl_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_log.size = Vector2(680, 60)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(0, 0, 0, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash_rect)

	# кнопки действий
	var grid_holder := Control.new()
	grid_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(grid_holder)
	actions_grid = GridContainer.new()
	actions_grid.columns = 2
	actions_grid.position = Vector2(16, 905)
	actions_grid.size = Vector2(688, 360)
	actions_grid.add_theme_constant_override("h_separation", 12)
	actions_grid.add_theme_constant_override("v_separation", 12)
	grid_holder.add_child(actions_grid)

	_build_menu()
	_build_qte()
	_build_struggle()
	_build_rest()
	_build_end()


func _menu_chip_row(parent: Control, key: String, labels: Array, y: float, sel: int, cb: Callable) -> void:
	var btns := []
	var n := labels.size()
	var w := 660.0 / n - 8.0
	for i in range(n):
		var b := _btn(labels[i], 20, parent, Vector2(30 + i * (w + 10), y), Vector2(w, 64), cb.bind(i))
		btns.append(b)
	menu_chip_rows[key] = btns
	_update_chip_row(key, sel)


func _update_chip_row(key: String, sel: int) -> void:
	var btns: Array = menu_chip_rows[key]
	for i in range(btns.size()):
		btns[i].modulate = Color("ffd54a") if i == sel else Color("8a93a8")


func _build_menu() -> void:
	ov_menu = _overlay()
	_lbl("BJJ ARENA", 56, Color("ffd54a"), ov_menu, Vector2(30, 160), 660)
	_lbl("Godot Edition · джиу-джитсу на ковре", 20, Color("aab6cc"), ov_menu, Vector2(30, 240), 660)
	_lbl("СЛОЖНОСТЬ", 17, Color("8a93a8"), ov_menu, Vector2(30, 320), 660)
	_menu_chip_row(ov_menu, "diff", ["Белый", "Пурпурный", "Чёрный"], 352, 0,
		func(i: int) -> void:
			diff = i
			_spawn_foe()
			_update_chip_row("diff", i))
	_lbl("РАУНДЫ", 17, Color("8a93a8"), ov_menu, Vector2(30, 440), 660)
	_menu_chip_row(ov_menu, "rounds", ["1", "3", "5"], 472, 1,
		func(i: int) -> void:
			total_rounds = [1, 3, 5][i]
			_update_chip_row("rounds", i))
	_lbl("ДЛИТЕЛЬНОСТЬ РАУНДА", 17, Color("8a93a8"), ov_menu, Vector2(30, 560), 660)
	_menu_chip_row(ov_menu, "time", ["1:00", "1:30", "2:00"], 592, 1,
		func(i: int) -> void:
			round_time = [60.0, 90.0, 120.0][i]
			_update_chip_row("time", i))
	var start := _btn("НА КОВЁР!", 30, ov_menu, Vector2(160, 720), Vector2(400, 96), _start_match)
	start.modulate = Color("ffd54a")
	_lbl("Очки: тейкдаун 2 · свип 2 · проход 3 · маунт 4 · спина 4\nПобеда по очкам или сабмишном. Осс!", 16,
		Color("8a93a8"), ov_menu, Vector2(30, 860), 660)


func _build_qte() -> void:
	ov_qte = _overlay()
	qte_name_lbl = _lbl("Приём", 34, Color.WHITE, ov_qte, Vector2(30, 420), 660)
	qte_track = _rect(Color("1a2233"), Vector2(60, 500), Vector2(600, 46), ov_qte)
	qte_zone = _rect(Color("40916c"), Vector2(0, 0), Vector2(150, 46), qte_track)
	qte_mark = _rect(Color("ffd54a"), Vector2(0, -4), Vector2(8, 54), qte_track)
	_lbl("Жми СТОП, когда маркер в зелёной зоне!", 18, Color("aab6cc"), ov_qte, Vector2(30, 566), 660)
	_btn("СТОП!", 32, ov_qte, Vector2(180, 640), Vector2(360, 100), _qte_stop)


func _build_struggle() -> void:
	ov_st = _overlay()
	st_name_lbl = _lbl("ДОЖИМАЙ!", 32, Color.WHITE, ov_st, Vector2(30, 380), 660)
	st_sub_lbl = _lbl("Тапай изо всех сил!", 18, Color("aab6cc"), ov_st, Vector2(30, 432), 660)
	var track := _rect(Color("3d1220"), Vector2(60, 490), Vector2(600, 36), ov_st)
	st_fill = _rect(Color("52b788"), Vector2(0, 0), Vector2(300, 36), track)
	st_timer_lbl = _lbl("6.0", 20, Color("ffd54a"), ov_st, Vector2(30, 540), 660)
	st_btn = _btn("ТАП!", 36, ov_st, Vector2(160, 610), Vector2(400, 130), _st_tap)


func _build_rest() -> void:
	ov_rest = _overlay()
	rest_title = _lbl("Конец раунда", 40, Color("ffd54a"), ov_rest, Vector2(30, 420), 660)
	rest_detail = _lbl("", 20, Color("d5deef"), ov_rest, Vector2(30, 490), 660)
	rest_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rest_detail.size = Vector2(660, 160)
	_btn("СЛЕДУЮЩИЙ РАУНД", 26, ov_rest, Vector2(140, 680), Vector2(440, 92), _start_round)


func _build_end() -> void:
	ov_end = _overlay()
	end_title = _lbl("ПОБЕДА!", 52, Color("74c69d"), ov_end, Vector2(30, 400), 660)
	end_detail = _lbl("", 20, Color("d5deef"), ov_end, Vector2(30, 480), 660)
	end_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_detail.size = Vector2(660, 160)
	_btn("ЕЩЁ БОЙ", 28, ov_end, Vector2(160, 660), Vector2(400, 92), _start_match)
	_btn("В МЕНЮ", 22, ov_end, Vector2(220, 770), Vector2(280, 70),
		func() -> void:
			screen = "menu"
			_show_only("menu"))


func _show_only(which: String) -> void:
	ov_menu.visible = which == "menu"
	ov_qte.visible = which == "qte"
	ov_st.visible = which == "struggle"
	ov_rest.visible = which == "rest"
	ov_end.visible = which == "end"


func _set_log(msg: String, c: Color = Color("cfe3ff")) -> void:
	lbl_log.text = msg
	lbl_log.add_theme_color_override("font_color", c)


func _flash(c: Color) -> void:
	flash_color = c
	flash_alpha = 0.4


func _fmt_clock(s: float) -> String:
	var t := int(ceil(max(0.0, s)))
	return "%d:%02d" % [t / 60, t % 60]


func _update_hud() -> void:
	lbl_pts_you.text = str(pts_you)
	lbl_pts_foe.text = str(pts_foe)
	lbl_adv_you.text = "Преим.: %d" % adv_you
	lbl_adv_foe.text = "Преим.: %d" % adv_foe
	lbl_clock.text = _fmt_clock(clock)
	lbl_round.text = "РАУНД %d/%d" % [round_no, total_rounds]
	bar_you.size.x = 336.0 * stam_you / 100.0
	bar_foe.size.x = 336.0 * stam_foe / 100.0
	bar_foe.position.x = 368.0 + 336.0 * (1.0 - stam_foe / 100.0)
	var p: Dictionary = POSITIONS[pos]
	lbl_pos.text = p["label"]
	lbl_pos_side.text = p["side"]


func _render_actions(force := false) -> void:
	if not force and rendered_pos == pos:
		_update_action_buttons()
		return
	rendered_pos = pos
	for child in actions_grid.get_children():
		child.queue_free()
	action_buttons = []
	var acts: Array = PLAYER_ACTIONS[pos]
	for a in acts:
		var b := Button.new()
		b.text = a["name"] + "\n" + a["hint"]
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(338, 92)
		if a.get("cls", "") == "sub":
			b.modulate = Color("ff9d8a")
		elif a.get("cls", "") == "rest":
			b.modulate = Color("b8bdd0")
		b.pressed.connect(_player_action.bind(a))
		actions_grid.add_child(b)
		action_buttons.append({"btn": b, "act": a, "is_def": false})
	var d := Button.new()
	d.text = "Защита 🛡\nсбить атаку · 4 сек"
	d.add_theme_font_size_override("font_size", 22)
	d.custom_minimum_size = Vector2(338, 92)
	d.modulate = Color("8fdcb0")
	d.pressed.connect(_defense_action)
	actions_grid.add_child(d)
	action_buttons.append({"btn": d, "act": {}, "is_def": true})
	_update_action_buttons()


func _update_action_buttons() -> void:
	for item in action_buttons:
		if item["is_def"]:
			item["btn"].disabled = game_time < def_cooldown or stam_you < 8.0
		else:
			item["btn"].disabled = stam_you < item["act"]["cost"]


# ═══════════════════════ ДЕЙСТВИЯ ═══════════════════════
func _defense_action() -> void:
	if screen != "fight":
		return
	stam_you = clamp(stam_you - 8.0, 0.0, 100.0)
	def_until = game_time + 4.0
	def_cooldown = game_time + 9.0
	_set_log("Вы в глухой защите: хват сбит, атаки соперника слабее.", Color("74c69d"))
	_update_action_buttons()


func _player_action(a: Dictionary) -> void:
	if screen != "fight":
		return
	if a.has("restore"):
		stam_you = clamp(stam_you + a["restore"], 0.0, 100.0)
		_set_log("Вы контролируете позицию и восстанавливаете дыхание…", Color("9ad1ff"))
		_update_action_buttons()
		return
	stam_you = clamp(stam_you - a["cost"], 0.0, 100.0)
	_open_qte(a)


func _open_qte(a: Dictionary) -> void:
	screen = "qte"
	var d: Dictionary = DIFFS[diff]
	var stam_f := 0.7 + 0.3 * stam_you / 100.0
	var zone_w: float = clamp(d["zone"] * (0.6 + a["chance"]) * stam_f, 0.10, 0.5)
	qte = {"action": a, "t": randf(), "dir": 1.0,
		"speed": d["speed"] * randf_range(0.95, 1.1),
		"zone_start": randf_range(0.12, 0.88 - zone_w), "zone_w": zone_w}
	qte_name_lbl.text = a["name"]
	qte_zone.position.x = qte["zone_start"] * 600.0
	qte_zone.size.x = zone_w * 600.0
	_show_only("qte")


func _qte_stop() -> void:
	if qte.is_empty():
		return
	var q := qte
	qte = {}
	var a: Dictionary = q["action"]
	var hit: bool = q["t"] >= q["zone_start"] and q["t"] <= q["zone_start"] + q["zone_w"]
	screen = "fight"
	_show_only("none")
	if hit:
		if a.has("sub"):
			_start_struggle("attack", a["sub"])
			return
		_apply_success(a)
	else:
		_flash(Color("c0392b"))
		cam_shake = 0.25
		_set_log("Мимо! %s не прошёл — соперник защитился." % a["name"], Color("ff9d9d"))
		stam_foe = clamp(stam_foe - 4.0, 0.0, 100.0)
	_render_actions()
	_update_hud()


func _apply_success(a: Dictionary) -> void:
	_flash(Color("2ecc71"))
	cam_shake = 0.4
	pts_you += int(a.get("pts", 0))
	if a.has("to"):
		pos = a["to"]
	_set_log("%s — успех!" % a["name"], Color("9dffb0"))
	_render_actions()
	_update_hud()


func _start_struggle(mode: String, sub_name: String) -> void:
	screen = "struggle"
	var d: Dictionary = DIFFS[diff]
	var def_bonus := 14.0 if (mode == "defense" and game_time < def_until) else 0.0
	var start_fill: float = d["atk_start"] if mode == "attack" else d["def_start"] + def_bonus
	st = {"mode": mode, "fill": start_fill, "time_left": 6.0, "sub": sub_name}
	if mode == "attack":
		st_name_lbl.text = "🔥 ДОЖИМАЙ: %s!" % sub_name.to_upper()
		st_sub_lbl.text = "Тапай, чтобы дожать, пока соперник не вырвался!"
		st_btn.text = "ДОЖАТЬ!"
	else:
		st_name_lbl.text = "⚠ ЗАЩИЩАЙСЯ: %s!" % sub_name.to_upper()
		st_sub_lbl.text = "Тапай, чтобы вырваться, пока не задушили!"
		st_btn.text = "ВЫРВАТЬСЯ!"
	_update_struggle_ui()
	_show_only("struggle")


func _update_struggle_ui() -> void:
	st_fill.size.x = 600.0 * clamp(st["fill"], 0.0, 100.0) / 100.0
	st_timer_lbl.text = "%.1f" % st["time_left"]


func _st_tap() -> void:
	if st.is_empty():
		return
	var d: Dictionary = DIFFS[diff]
	var stam_f := 0.7 + 0.3 * stam_you / 100.0
	st["fill"] += d["tap"] * stam_f
	cam_shake = min(cam_shake + 0.06, 0.3)
	if st["fill"] >= 100.0:
		_finish_struggle(true)
	else:
		_update_struggle_ui()


func _finish_struggle(player_won: bool) -> void:
	var s := st
	st = {}
	screen = "fight"
	_show_only("none")
	stam_you = clamp(stam_you - 10.0, 0.0, 100.0)
	stam_foe = clamp(stam_foe - 10.0, 0.0, 100.0)
	if s["mode"] == "attack":
		if player_won:
			_end_match("you", "Победа %s! Соперник постучал. 🥋" % s["sub"])
			return
		adv_you += 1
		_flash(Color("f0a500"))
		_set_log("Соперник вырвался из %s… но вы получили преимущество!" % s["sub"], Color("ffd54a"))
	else:
		if player_won:
			adv_foe += 1
			_flash(Color("2ecc71"))
			_set_log("Вы вырвались! Соперник получил преимущество за попытку.", Color("9dffb0"))
		else:
			_end_match("foe", "Соперник провёл %s. Вы постучали…" % s["sub"])
			return
	_render_actions()
	_update_hud()


func _ai_act() -> void:
	var d: Dictionary = DIFFS[diff]
	var acts: Array = AI_ACTIONS[pos]
	if acts.is_empty():
		return
	var total := 0.0
	for a in acts:
		total += a["w"]
	var r := randf() * total
	var chosen: Dictionary = acts[0]
	for a in acts:
		r -= a["w"]
		if r <= 0.0:
			chosen = a
			break
	if stam_foe < 15.0:
		stam_foe = clamp(stam_foe + 18.0, 0.0, 100.0)
		_set_log("Соперник тяжело дышит и держит позицию…", Color("c9c9c9"))
		return
	stam_foe = clamp(stam_foe - 14.0, 0.0, 100.0)
	var stam_f := 0.7 + 0.3 * stam_foe / 100.0
	var chance: float = chosen["chance"] * d["ai_chance"] * stam_f
	if game_time < def_until:
		chance *= 0.45
	chance = clamp(chance, 0.05, 0.9)
	if chosen.has("sub"):
		if randf() < chance:
			_set_log(chosen["msg"], Color("ff9d9d"))
			_start_struggle("defense", chosen["sub"])
		else:
			_set_log("Соперник попытался поймать %s — вы вовремя убрали руки." % chosen["sub"])
		return
	if randf() < chance:
		pts_foe += int(chosen.get("pts", 0))
		pos = chosen["to"]
		_flash(Color("e67e22"))
		cam_shake = 0.4
		_set_log(chosen["msg"], Color("ffbf8f"))
		_render_actions()
	else:
		_set_log("Соперник пробует %s — вы защитились!" % chosen["name"])
	_update_hud()


# ═══════════════════════ МАТЧ / РАУНДЫ ═══════════════════════
func _start_match() -> void:
	pts_you = 0
	pts_foe = 0
	adv_you = 0
	adv_foe = 0
	round_no = 1
	lbl_foe_name.text = DIFFS[diff]["name"]
	_start_round()


func _start_round() -> void:
	pos = "standing"
	clock = round_time
	if round_no == 1:
		stam_you = 100.0
		stam_foe = 100.0
	else:
		stam_foe = clamp(stam_foe + 45.0, 0.0, 100.0)
	def_until = 0.0
	def_cooldown = 0.0
	ai_timer = randf_range(DIFFS[diff]["ai_min"], DIFFS[diff]["ai_max"])
	screen = "fight"
	_show_only("none")
	_set_log("Раунд %d. Пожали руки — боремся! Осс!" % round_no, Color("ffd54a"))
	_render_actions(true)
	_update_hud()


func _end_round() -> void:
	qte = {}
	st = {}
	if round_no >= total_rounds:
		_final_result()
		return
	screen = "rest"
	round_no += 1
	stam_you = clamp(stam_you + 45.0, 0.0, 100.0)
	rest_title.text = "Конец раунда %d" % (round_no - 1)
	var status := "Равный бой. Решает следующий раунд!"
	if pts_you > pts_foe:
		status = "Вы ведёте — так держать!"
	elif pts_you < pts_foe:
		status = "Вы отстаёте — нужен проход или сабмишн!"
	rest_detail.text = "Счёт: %d : %d (преим. %d:%d)\n%s\nПередышка: силы частично восстановлены." % [pts_you, pts_foe, adv_you, adv_foe, status]
	_show_only("rest")


func _final_result() -> void:
	if pts_you != pts_foe:
		var w := "you" if pts_you > pts_foe else "foe"
		_end_match(w, "по очкам %d:%d" % [pts_you, pts_foe])
	elif adv_you != adv_foe:
		var w2 := "you" if adv_you > adv_foe else "foe"
		_end_match(w2, "по преимуществам %d:%d (очки %d:%d)" % [adv_you, adv_foe, pts_you, pts_foe])
	else:
		_end_match("draw", "абсолютно равный бой %d:%d" % [pts_you, pts_foe])


func _end_match(winner: String, detail: String) -> void:
	screen = "end"
	qte = {}
	st = {}
	if winner == "you":
		end_title.text = "🏆 ПОБЕДА!"
		end_title.add_theme_color_override("font_color", Color("74c69d"))
	elif winner == "foe":
		end_title.text = "ПОРАЖЕНИЕ"
		end_title.add_theme_color_override("font_color", Color("eb5757"))
	else:
		end_title.text = "🤝 НИЧЬЯ"
		end_title.add_theme_color_override("font_color", Color("ffd54a"))
	end_detail.text = "%s\nСоперник: %s · раундов: %d" % [detail, DIFFS[diff]["name"], total_rounds]
	_show_only("end")


# ═══════════════════════ ЦИКЛ ═══════════════════════
func _process(delta: float) -> void:
	game_time += delta

	if screen == "fight":
		clock -= delta
		var regen := 4.5 if game_time < def_until else 2.8
		stam_you = clamp(stam_you + regen * delta, 0.0, 100.0)
		stam_foe = clamp(stam_foe + DIFFS[diff]["ai_regen"] * delta, 0.0, 100.0)
		ai_timer -= delta
		if ai_timer <= 0.0:
			_ai_act()
			ai_timer = randf_range(DIFFS[diff]["ai_min"], DIFFS[diff]["ai_max"])
		if clock <= 0.0 and screen == "fight":
			_end_round()
		_update_action_buttons()
		_update_hud()
	elif screen == "qte" and not qte.is_empty():
		qte["t"] += qte["dir"] * qte["speed"] * delta
		if qte["t"] > 1.0:
			qte["t"] = 1.0
			qte["dir"] = -1.0
		if qte["t"] < 0.0:
			qte["t"] = 0.0
			qte["dir"] = 1.0
		qte_mark.position.x = qte["t"] * 600.0 - 4.0
		clock -= delta * 0.5
	elif screen == "struggle" and not st.is_empty():
		st["time_left"] -= delta
		st["fill"] -= DIFFS[diff]["drain"] * delta
		if st["fill"] <= 0.0:
			_finish_struggle(false)
		elif st["time_left"] <= 0.0:
			_finish_struggle(st["mode"] != "attack")
		else:
			_update_struggle_ui()

	# вспышка
	if flash_alpha > 0.0:
		flash_alpha = max(0.0, flash_alpha - delta * 1.2)
		flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, flash_alpha)

	# позы бойцов
	var sc: Dictionary = SCENES.get(pos, SCENES["standing"])
	var intensity := 4.5 if screen == "struggle" else (1.4 if screen == "fight" else 0.8)
	_apply_fighter(you, sc["you"], "you", delta, intensity)
	_apply_fighter(foe, sc["foe"], "foe", delta, intensity)

	# толпа покачивается
	for i in range(crowd_planes.size()):
		crowd_planes[i].position.y = 2.8 + sin(game_time * 1.4 + i * 1.7) * 0.045

	_update_camera(delta)


func _apply_fighter(F: Dictionary, cfg: Dictionary, who: String, delta: float, intensity: float) -> void:
	if F.is_empty():
		return
	var k := 1.0 - exp(-7.0 * delta)
	var root: Node3D = F["root"]
	root.position = root.position.lerp(cfg["p"], k)
	var target_q := Quaternion(Vector3.UP, cfg["yaw"]) * Quaternion(Vector3.RIGHT, cfg["pitch"])
	root.quaternion = root.quaternion.slerp(target_q, k)
	var joints: Dictionary = cfg["j"]
	var wob: Dictionary = wobble[who]
	for j in joints.keys():
		if not F.has(j):
			continue
		var e: Vector3 = joints[j]
		var w: Vector3 = wob[j]
		var amp := 0.05 * intensity
		var eu := Vector3(
			e.x + sin(game_time * w.y + w.x) * amp,
			e.y,
			e.z + cos(game_time * w.y * 0.8 + w.z) * amp * 0.6)
		var tq := Quaternion.from_euler(eu)
		var node: Node3D = F[j]
		node.quaternion = node.quaternion.slerp(tq, k)


func _update_camera(delta: float) -> void:
	var struggling := screen == "struggle"
	var target_dist := 2.1 if struggling else (3.1 if pos == "standing" else 2.7)
	var target_h := 1.05 if struggling else (1.4 if pos == "standing" else 1.7)
	cam_dist += (target_dist - cam_dist) * (1.0 - exp(-2.0 * delta))
	cam_height += (target_h - cam_height) * (1.0 - exp(-2.0 * delta))
	cam_angle += delta * (0.25 if screen == "menu" else 0.12)
	cam_shake = max(0.0, cam_shake - delta * 1.2)
	var shx := (randf() - 0.5) * cam_shake * 0.12
	var shy := (randf() - 0.5) * cam_shake * 0.12
	cam.position = Vector3(sin(cam_angle) * cam_dist + shx, cam_height + shy, cos(cam_angle) * cam_dist)
	cam.look_at(Vector3(0, 0.45, 0))
