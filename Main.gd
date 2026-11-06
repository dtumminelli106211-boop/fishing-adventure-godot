extends Control

const SAVE_PATH := "user://fishing_adventure_save.json"
const RARITIES := ["Junk", "Common", "Uncommon", "Unusual", "Rare", "Super Rare", "Epic", "Ultra", "Legendary", "Mythical", "Ancient", "Divine", "Celestial", "Cosmic", "Transcendent", "Secret"]
const LOCATIONS := [
	{"name":"Quiet Pond", "level":1, "cost":0, "fish":["Minnow","Bluegill","Pond Carp","Mudskipper","Old Boot","Golden Koi"]},
	{"name":"Sunlit Lake", "level":2, "cost":150, "fish":["Bass","Perch","Trout","Lake Sturgeon","Silver Pike","Sunfish"]},
	{"name":"Forest River", "level":3, "cost":350, "fish":["Salmon","Catfish","Rainbow Trout","River Eel","Otterfish","Mossback"]},
	{"name":"Coral Reef", "level":4, "cost":700, "fish":["Clownfish","Parrotfish","Lionfish","Reef Ray","Pearl Turtle","Coral Dragon"]},
	{"name":"Frozen Fjord", "level":6, "cost":1200, "fish":["Ice Perch","Snow Crab","Arctic Char","Frost Whale","Glacier Serpent","Aurora Salmon"]},
	{"name":"Deep Sea", "level":8, "cost":2200, "fish":["Anglerfish","Giant Squid","Blue Marlin","Abyss Shark","Leviathan","Ghost Nautilus"]},
	{"name":"Volcanic Trench", "level":11, "cost":4000, "fish":["Lava Eel","Magma Crab","Ashfin","Ember Kraken","Cinder Leviathan","Inferno Ray"]},
	{"name":"Ancient Ruins", "level":14, "cost":6500, "fish":["Relic Carp","Stone Guardian","Runic Ray","Temple Serpent","Lost Emperor","Chrono Whale"]},
	{"name":"Crystal Cavern", "level":18, "cost":10000, "fish":["Crystal Guppy","Prism Pike","Gemscale","Cave Phoenix","Starlight Koi","Prismatic Leviathan"]}
]
const BAITS := ["Basic", "Worm", "Shrimp", "Glow Bait", "Golden Bait", "Abyssal Bait"]
const BAIT_COSTS := {"Basic":0, "Worm":25, "Shrimp":60, "Glow Bait":120, "Golden Bait":300, "Abyssal Bait":600}
const BAIT_STOCK := {"Basic":999999, "Worm":5, "Shrimp":5, "Glow Bait":4, "Golden Bait":3, "Abyssal Bait":2}
const BAIT_BONUS := {"Basic":0, "Worm":1, "Shrimp":2, "Glow Bait":3, "Golden Bait":5, "Abyssal Bait":7}
const FISH_VALUES := [8, 15, 28, 45, 70, 110, 170, 260, 400, 600, 900, 1350, 2000, 3000, 4500, 7000]

var state: Dictionary
var hooked: Dictionary = {}
var progress := 0.0
var strain := 0.0
var resting := false
var last_click_msec := 0
var location_select: OptionButton
var bait_select: OptionButton
var stats_label: Label
var encounter_label: Label
var progress_bar: ProgressBar
var strain_bar: ProgressBar
var log_label: Label
var inventory_box: VBoxContainer
var tank_box: VBoxContainer
var shop_box: VBoxContainer
var location_box: VBoxContainer
var tank_select: OptionButton
var aquarium_art: Label
var main_column: VBoxContainer

func _ready() -> void:
	state = _load_state()
	_build_ui()
	_refresh()

func _default_state() -> Dictionary:
	return {"coins":1000, "level":1, "xp":0, "caught":0, "best":-1, "inventory":[], "tanks":[{"id":1,"name":"Starter Aquarium","capacity":12,"fish":[]}], "active_tank":1, "unlocked":["Quiet Pond"], "location":"Quiet Pond", "bait":"Basic", "bait_stock":{"Worm":0,"Shrimp":0,"Glow Bait":0,"Golden Bait":0,"Abyssal Bait":0}, "upgrades":{"rod":0,"boat":0}, "log":["Welcome! Cast a line to start fishing."]}

func _load_state() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return _default_state()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return _default_state()
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.has("coins") and parsed.has("inventory") and parsed.has("tanks"):
		var result := _default_state()
		for key in parsed:
			result[key] = parsed[key]
		return result
	return _default_state()

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state))

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("071525")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 18
	scroll.offset_top = 14
	scroll.offset_right = -18
	scroll.offset_bottom = -14
	add_child(scroll)
	main_column = VBoxContainer.new()
	main_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_column.add_theme_constant_override("separation", 12)
	scroll.add_child(main_column)
	var title := Label.new()
	title.text = "🎣  FISHING ADVENTURE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	main_column.add_child(title)
	stats_label = _label("", 18)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_column.add_child(stats_label)
	var travel_row := HBoxContainer.new()
	main_column.add_child(travel_row)
	location_select = OptionButton.new()
	location_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location_select.item_selected.connect(_on_location_selected)
	travel_row.add_child(location_select)
	bait_select = OptionButton.new()
	bait_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bait_select.item_selected.connect(_on_bait_selected)
	travel_row.add_child(bait_select)
	var cast := _button("🎣 CAST LINE — $5", _cast)
	cast.custom_minimum_size.y = 54
	main_column.add_child(cast)
	var encounter_panel := _panel("CATCH ENCOUNTER")
	main_column.add_child(encounter_panel)
	encounter_label = _label("Cast your line to find a fish.", 20)
	encounter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	encounter_panel.add_child(encounter_label)
	var fish_row := HBoxContainer.new()
	encounter_panel.add_child(fish_row)
	var reel := _button("REEL IN", _reel)
	reel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fish_row.add_child(reel)
	var rest := _button("REST / RESUME", _toggle_rest)
	fish_row.add_child(rest)
	var release := _button("RELEASE", _release)
	fish_row.add_child(release)
	progress_bar = ProgressBar.new()
	progress_bar.max_value = 100
	encounter_panel.add_child(_label("Catch progress", 14))
	encounter_panel.add_child(progress_bar)
	strain_bar = ProgressBar.new()
	strain_bar.max_value = 100
	encounter_panel.add_child(_label("Line tension", 14))
	encounter_panel.add_child(strain_bar)
	var aquarium_panel := _panel("AQUARIUM")
	main_column.add_child(aquarium_panel)
	var tank_row := HBoxContainer.new()
	aquarium_panel.add_child(tank_row)
	tank_select = OptionButton.new()
	tank_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tank_select.item_selected.connect(_on_tank_selected)
	tank_row.add_child(tank_select)
	tank_row.add_child(_button("+ Aquarium", _buy_tank))
	aquarium_art = _label("A peaceful aquarium", 17)
	aquarium_art.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aquarium_panel.add_child(aquarium_art)
	tank_box = VBoxContainer.new()
	aquarium_panel.add_child(tank_box)
	var inventory_panel := _panel("FISH INVENTORY")
	main_column.add_child(inventory_panel)
	inventory_box = VBoxContainer.new()
	inventory_panel.add_child(inventory_box)
	var shop_panel := _panel("BAIT & UPGRADES")
	main_column.add_child(shop_panel)
	shop_box = VBoxContainer.new()
	shop_panel.add_child(shop_box)
	var world_panel := _panel("LOCATIONS")
	main_column.add_child(world_panel)
	location_box = VBoxContainer.new()
	world_panel.add_child(location_box)
	var save_row := HBoxContainer.new()
	main_column.add_child(save_row)
	save_row.add_child(_button("SAVE", _manual_save))
	save_row.add_child(_button("RESET", _reset))
	log_label = _label("", 13)
	main_column.add_child(log_label)

func _panel(title: String) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	var heading := _label(title, 19)
	heading.add_theme_color_override("font_color", Color("75d7ff"))
	panel.add_child(heading)
	return panel

func _label(text: String, size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	return button

func _process(delta: float) -> void:
	if hooked.is_empty():
		return
	if resting:
		strain = maxf(0.0, strain - 55.0 * delta)
	elif Time.get_ticks_msec() - last_click_msec > 650:
		strain = maxf(0.0, strain - 8.0 * delta)
	strain_bar.value = strain

func _on_location_selected(index: int) -> void:
	var loc: Dictionary = LOCATIONS[index]
	if not state.unlocked.has(loc.name):
		_note("Unlock this location in the world list first.")
		_refresh()
		return
	state.location = loc.name
	_note("Traveling to " + loc.name + ".")
	_refresh()

func _on_bait_selected(index: int) -> void:
	state.bait = BAITS[index]
	_save()

func _on_tank_selected(index: int) -> void:
	state.active_tank = int(state.tanks[index].id)
	_refresh()

func _cast() -> void:
	if not hooked.is_empty():
		_note("A fish is already hooked!")
		return
	if state.coins < 5:
		_note("You need $5 to cast.")
		return
	var bait: String = state.bait
	if bait != "Basic":
		if int(state.bait_stock.get(bait, 0)) <= 0:
			_note("Out of " + bait + ". Buy more or select Basic.")
			return
		state.bait_stock[bait] = int(state.bait_stock[bait]) - 1
	state.coins -= 5
	var location := _current_location()
	var species: Array = location.fish
	var fish_name: String = species[randi() % species.size()]
	var tier := _roll_tier(bait)
	hooked = {"id":str(Time.get_ticks_msec()) + str(randi()), "name":fish_name, "tier":tier, "location":location.name, "value":FISH_VALUES[tier]}
	progress = 0.0
	strain = 0.0
	resting = false
	last_click_msec = Time.get_ticks_msec()
	_note("A bite! " + fish_name + " — " + RARITIES[tier] + ".")
	_refresh()

func _roll_tier(bait: String) -> int:
	var max_tier := mini(15, int((state.level - 1) / 2) + LOCATIONS.find(_current_location()) + 2)
	var weights := [300.0,250.0,180.0,130.0,85.0,60.0,42.0,28.0,18.0,12.0,8.0,5.0,3.0,2.0,1.0,0.45]
	var total := 0.0
	for i in range(weights.size()):
		if i > max_tier:
			weights[i] = 0.0
		var source_index := maxi(0, i - int(BAIT_BONUS[bait]))
		if i <= max_tier:
			total += weights[source_index]
	var roll := randf() * total
	for i in range(weights.size()):
		if i > max_tier:
			continue
		roll -= weights[maxi(0, i - int(BAIT_BONUS[bait]))]
		if roll <= 0.0:
			return i
	return 0

func _reel() -> void:
	if hooked.is_empty() or resting:
		return
	var gap := Time.get_ticks_msec() - last_click_msec
	var heat := 0.0
	if gap < 120:
		heat = 2.8
	elif gap < 190:
		heat = 1.8
	elif gap < 280:
		heat = 1.0
	var tier := int(hooked.tier)
	strain = minf(100.0, strain + 3.0 + tier * 0.9 + heat)
	progress = minf(100.0, progress + 100.0 / float(8 + tier * 6) * (1.0 + float(state.upgrades.rod) * 0.035))
	last_click_msec = Time.get_ticks_msec()
	if strain >= 100.0:
		_note("The line snapped! " + hooked.name + " escaped.")
		hooked = {}
		progress = 0.0
		strain = 0.0
	elif progress >= 100.0:
		_land_fish()
	else:
		encounter_label.text = hooked.name + " • " + RARITIES[tier] + "\nKeep reeling, but watch the tension!"
		progress_bar.value = progress
		strain_bar.value = strain
	_save()

func _toggle_rest() -> void:
	if hooked.is_empty():
		return
	resting = not resting
	last_click_msec = Time.get_ticks_msec()
	_note("Resting to cool the line." if resting else "Back to reeling!")

func _release() -> void:
	if hooked.is_empty():
		return
	_note(hooked.name + " was released.")
	hooked = {}
	progress = 0.0
	strain = 0.0
	_refresh()

func _land_fish() -> void:
	var fish := hooked.duplicate(true)
	hooked = {}
	progress = 0.0
	strain = 0.0
	state.inventory.push_front(fish)
	state.caught += 1
	state.best = maxi(int(state.best), int(fish.tier))
	state.coins += int(fish.value) + 8
	state.xp += 12 + int(fish.tier) * 8
	while state.xp >= _xp_needed():
		state.xp -= _xp_needed()
		state.level += 1
		_note("Level up! You reached level " + str(state.level) + ".")
	_note("Caught " + fish.name + "! Earned $" + str(int(fish.value) + 8) + ".")
	_refresh()

func _xp_needed() -> int:
	return 60 + (int(state.level) - 1) * 35

func _current_location() -> Dictionary:
	for loc in LOCATIONS:
		if loc.name == state.location:
			return loc
	return LOCATIONS[0]

func _active_tank() -> Dictionary:
	for tank in state.tanks:
		if int(tank.id) == int(state.active_tank):
			return tank
	return state.tanks[0]

func _fish_value(fish: Dictionary) -> int:
	return int(round(float(fish.value) * (1.0 + int(state.upgrades.boat) * 0.2) * (1.0 + int(state.upgrades.rod) * 0.08)))

func _sell_inventory(fish_id: String) -> void:
	for i in range(state.inventory.size()):
		var fish: Dictionary = state.inventory[i]
		if str(fish.id) == fish_id:
			var value := _fish_value(fish)
			state.inventory.remove_at(i)
			state.coins += value
			_note("Sold " + fish.name + " for $" + str(value) + ".")
			_refresh()
			return

func _place_fish(fish_id: String) -> void:
	var tank := _active_tank()
	if tank.fish.size() >= int(tank.capacity):
		_note("Aquarium full. Remove a fish first.")
		return
	for i in range(state.inventory.size()):
		var fish: Dictionary = state.inventory[i]
		if str(fish.id) == fish_id:
			tank.fish.append(state.inventory.pop_at(i))
			_note("Placed " + fish.name + " in the aquarium.")
			_refresh()
			return

func _remove_fish(fish_id: String) -> void:
	var tank := _active_tank()
	for i in range(tank.fish.size()):
		var fish: Dictionary = tank.fish[i]
		if str(fish.id) == fish_id:
			state.inventory.push_front(tank.fish.pop_at(i))
			_note("Returned " + fish.name + " to inventory.")
			_refresh()
			return

func _sell_tank_fish(fish_id: String) -> void:
	var tank := _active_tank()
	for i in range(tank.fish.size()):
		var fish: Dictionary = tank.fish[i]
		if str(fish.id) == fish_id:
			var value := _fish_value(fish)
			tank.fish.remove_at(i)
			state.coins += value
			_note("Sold " + fish.name + " for $" + str(value) + ".")
			_refresh()
			return

func _buy_bait(bait: String) -> void:
	var cost := int(BAIT_COSTS[bait])
	if state.coins < cost:
		_note("Not enough coins to buy " + bait + ".")
		return
	state.coins -= cost
	state.bait_stock[bait] = int(state.bait_stock.get(bait, 0)) + int(BAIT_STOCK[bait])
	_note("Bought " + bait + " bait.")
	_refresh()

func _upgrade(kind: String) -> void:
	var level := int(state.upgrades[kind])
	var cost := 250 * (level + 1) if kind == "rod" else 500 * (level + 1)
	if kind == "boat" and level >= 3:
		_note("Boat upgrade is maxed.")
		return
	if state.coins < cost:
		_note("Need $" + str(cost) + " for this upgrade.")
		return
	state.coins -= cost
	state.upgrades[kind] = level + 1
	_note(kind.capitalize() + " upgraded!")
	_refresh()

func _buy_tank() -> void:
	if state.tanks.size() >= 4:
		_note("You own all four aquariums.")
		return
	var cost := 1000 if state.tanks.size() == 1 else 3000 if state.tanks.size() == 2 else 6000
	if state.coins < cost:
		_note("Need $" + str(cost) + " for another aquarium.")
		return
	var next_id := 1
	for tank in state.tanks:
		next_id = maxi(next_id, int(tank.id) + 1)
	state.coins -= cost
	state.tanks.append({"id":next_id,"name":"Aquarium " + str(next_id),"capacity":12,"fish":[]})
	state.active_tank = next_id
	_note("Unlocked Aquarium " + str(next_id) + "!")
	_refresh()

func _unlock_location(name: String) -> void:
	for loc in LOCATIONS:
		if loc.name == name and not state.unlocked.has(name):
			if state.level < loc.level or state.coins < loc.cost:
				_note("Requires level " + str(loc.level) + " and $" + str(loc.cost) + ".")
				return
			state.coins -= loc.cost
			state.unlocked.append(name)
			_note("Unlocked " + name + "!")
			_refresh()
			return

func _travel(name: String) -> void:
	state.location = name
	_note("Traveling to " + name + ".")
	_refresh()

func _note(message: String) -> void:
	state.log.push_front(message)
	while state.log.size() > 8:
		state.log.pop_back()
	if is_instance_valid(log_label):
		log_label.text = "\n".join(state.log)
	_save()

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _refresh() -> void:
	stats_label.text = "$%s   •   Level %s (XP %s/%s)   •   Caught %s   •   Best: %s" % [str(state.coins), str(state.level), str(state.xp), str(_xp_needed()), str(state.caught), "—" if int(state.best) < 0 else RARITIES[int(state.best)]]
	location_select.clear()
	for loc in LOCATIONS:
		location_select.add_item(("✓ " if state.unlocked.has(loc.name) else "🔒 ") + loc.name)
	location_select.select(maxi(0, LOCATIONS.find(_current_location())))
	bait_select.clear()
	for bait in BAITS:
		bait_select.add_item(bait + ("" if bait == "Basic" else " x" + str(state.bait_stock.get(bait, 0))))
		if bait == state.bait:
			bait_select.select(BAITS.find(bait))
	if hooked.is_empty():
		encounter_label.text = "Cast your line to find a fish."
		progress_bar.value = 0
		strain_bar.value = 0
	else:
		encounter_label.text = hooked.name + " • " + RARITIES[int(hooked.tier)] + " • " + hooked.location + "\nReel carefully. Rest to cool the line."
		progress_bar.value = progress
		strain_bar.value = strain
	_refresh_tank()
	_refresh_inventory()
	_refresh_shop()
	_refresh_locations()
	log_label.text = "\n".join(state.log)
	_save()

func _refresh_tank() -> void:
	var tank := _active_tank()
	tank_select.clear()
	for entry in state.tanks:
		tank_select.add_item(entry.name)
		if int(entry.id) == int(state.active_tank):
			tank_select.select(state.tanks.find(entry))
	aquarium_art.text = "🐠  🌊  🐟\n" + tank.name + " — " + str(tank.fish.size()) + " / " + str(tank.capacity) + " fish"
	_clear_children(tank_box)
	if tank.fish.is_empty():
		tank_box.add_child(_label("No fish here yet.", 14))
	for fish in tank.fish:
		var row := HBoxContainer.new()
		row.add_child(_label(fish.name + " — " + RARITIES[int(fish.tier)] + " ($" + str(_fish_value(fish)) + ")", 14))
		row.add_child(_button("Remove", _remove_fish.bind(str(fish.id))))
		row.add_child(_button("Sell", _sell_tank_fish.bind(str(fish.id))))
		tank_box.add_child(row)

func _refresh_inventory() -> void:
	_clear_children(inventory_box)
	if state.inventory.is_empty():
		inventory_box.add_child(_label("Inventory empty — cast a line to catch fish.", 14))
	for fish in state.inventory:
		var row := HBoxContainer.new()
		row.add_child(_label(fish.name + " — " + RARITIES[int(fish.tier)] + " ($" + str(_fish_value(fish)) + ")", 14))
		row.add_child(_button("Place", _place_fish.bind(str(fish.id))))
		row.add_child(_button("Sell", _sell_inventory.bind(str(fish.id))))
		inventory_box.add_child(row)

func _refresh_shop() -> void:
	_clear_children(shop_box)
	for bait in BAITS:
		if bait == "Basic":
			continue
		shop_box.add_child(_button("Buy %s bait — $%s (%s charges)" % [bait, str(BAIT_COSTS[bait]), str(BAIT_STOCK[bait])], _buy_bait.bind(bait)))
	shop_box.add_child(_button("Upgrade rod — $%s" % str(250 * (int(state.upgrades.rod) + 1)), _upgrade.bind("rod")))
	var boat_button := _button("Upgrade boat — $%s" % str(500 * (int(state.upgrades.boat) + 1)), _upgrade.bind("boat"))
	boat_button.disabled = int(state.upgrades.boat) >= 3
	shop_box.add_child(boat_button)

func _refresh_locations() -> void:
	_clear_children(location_box)
	for loc in LOCATIONS:
		var row := HBoxContainer.new()
		var fish_text := ", ".join(loc.fish)
		row.add_child(_label("%s — Lv.%s / $%s\n%s" % [loc.name, str(loc.level), str(loc.cost), fish_text], 13))
		if state.unlocked.has(loc.name):
			row.add_child(_button("Travel", _travel.bind(loc.name)))
		else:
			row.add_child(_button("Unlock", _unlock_location.bind(loc.name)))
		location_box.add_child(row)

func _manual_save() -> void:
	_save()
	_note("Progress saved on this device.")

func _reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Erase this save and start a new adventure?"
	add_child(dialog)
	dialog.confirmed.connect(func():
		state = _default_state()
		hooked = {}
		progress = 0.0
		strain = 0.0
		_refresh()
		_note("A new adventure begins.")
	)
	dialog.popup_centered()
