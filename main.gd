extends Node3D

const SAVE_PATHS = [
    "user://save_slot_1.cfg",
    "user://save_slot_2.cfg",
    "user://save_slot_3.cfg"
]

const ITEMS = [
    {"id":"lemon", "name":"🍋 Лимон", "price":2, "time":3, "desc":"Сырьё для ларька. Даёт 3 стакана."},
    {"id":"culture", "name":"🧪 Исследовательский набор", "price":3, "time":4, "desc":"Нужен для абстрактных лабораторных исследований."},
    {"id":"syringe", "name":"💉 Медицинский набор", "price":1, "time":2, "desc":"Расходник для игрового эксперимента."},
    {"id":"strain", "name":"🧬 Образец штамма", "price":4, "time":5, "once":true, "desc":"Одноразовое игровое улучшение."},
    {"id":"rat", "name":"🐀 Лабораторная крыса", "price":12, "time":8, "desc":"Игровой носитель."},
    {"id":"immuno", "name":"💊 Защитный препарат", "price":6, "time":6, "desc":"Повышает шанс успеха игрового эксперимента."},
    {"id":"fleas", "name":"🦟 Усилитель штамма", "price":7, "time":6, "once":true, "desc":"Увеличивает игровую силу в 3 раза."},
    {"id":"gloves", "name":"🧤 Защитный комплект", "price":5, "time":5, "once":true, "desc":"Снижает игровой риск."},
    {"id":"incubator", "name":"🌡️ Исследовательская станция", "price":10, "time":6, "once":true, "desc":"Открывает лабораторное исследование."},
    {"id":"centrifuge", "name":"⚗️ Анализатор образцов", "price":25, "time":8, "once":true, "desc":"Открывает этап анализа."},
    {"id":"hood", "name":"🛡️ Защитный модуль", "price":40, "time":10, "once":true, "desc":"Снижает игровой риск."},
    {"id":"vpn", "name":"🔒 Цифровая защита", "price":20, "time":6, "once":true, "desc":"Снижает рост внимания полиции."},
    {"id":"sat", "name":"📡 Продвинутая защита", "price":150, "time":12, "once":true, "desc":"Сильно снижает внимание полиции."},
    {"id":"autom", "name":"🤖 Автоматизация ларька", "price":75, "time":10, "once":true, "desc":"Автоматически приносит $13 каждые 2 секунды."},
    {"id":"reactor", "name":"🏭 Модуль массового производства", "price":120, "time":15, "once":true, "desc":"Увеличивает награду за исследование."},
    {"id":"injector", "name":"💉 Автоматический модуль", "price":80, "time":12, "once":true, "desc":"Упрощает игровой эксперимент."},
    {"id":"aerosol", "name":"☣️ Эпидемический сценарий", "price":500, "time":20, "once":true, "desc":"Включает цепную игровую эпидемию."},
    {"id":"mut1", "name":"🧬 Мутация I", "price":900, "time":20, "once":true, "desc":"Увеличивает силу сценария в 10 раз."},
    {"id":"mut2", "name":"🧬 Мутация II", "price":5000, "time":25, "once":true, "desc":"Увеличивает силу сценария в 10 раз."},
    {"id":"mut3", "name":"🧬 Мутация III", "price":50000, "time":30, "once":true, "desc":"Увеличивает силу сценария в 10 раз."}
]

var state: Dictionary = {}
var selected_slot := 1
var started := false
var paused := false
var mouse_captured := false
var touch_move := {"forward":false, "backward":false, "left":false, "right":false}
var touch_look_last := Vector2.ZERO
var touch_look_active := false
var player: CharacterBody3D
var camera: Camera3D
var pitch := 0.0
var elapsed := 0.0
var auto_timer := 0.0
var day_timer := 0.0
var delivery_timer := 0.0
var deliveries: Array = []
var station_data: Array = []
var panel_name := ""
var message_text := "Подойди к объекту и нажми E"
var message_timer := 0.0

var root_ui: CanvasLayer
var hud: VBoxContainer
var stats_label: Label
var hint_label: Label
var log_label: RichTextLabel
var menu_layer: Control
var panel_layer: Control
var panel_content: VBoxContainer
var pause_layer: Control
var slot_option: OptionButton
var interact_prompt: Label
var crosshair: Label

func _ready() -> void:
    _build_world()
    _build_player()
    _build_ui()
    _fresh_state()
    _show_main_menu()
    set_process(true)
    set_process_input(true)

func _fresh_state() -> void:
    state = {
        "money": 15, "pop": 8000000000.0, "day": 1, "heat": 0.0, "leak": 0.0,
        "inv": {"lemon":0, "culture":0, "syringe":0, "rat":0, "immuno":0},
        "cups": 0, "raw": 0, "pure": 0, "infected": 0, "strain_level": 0,
        "killed": 0.0, "upg": {}, "log": ["Начни с лимонада: лимон $2 → 3 стакана × $5"],
        "inc": false, "cent": false, "door_open": false, "over": false, "win": false
    }
    deliveries.clear()
    day_timer = 0
    auto_timer = 0
    _refresh_hud()

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.025, 0.055, 0.075)
    sky_mat.sky_horizon_color = Color(0.12, 0.16, 0.17)
    sky.sky_material = sky_mat
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.35, 0.42, 0.43)
    environment.ambient_light_energy = 0.7
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_energy = 1.1
    add_child(sun)

    _make_box("Floor", Vector3(0,-0.3,0), Vector3(34,0.5,38), Color(0.13,0.16,0.16))
    _make_box("BackWall", Vector3(0,2,-18), Vector3(34,4,0.5), Color(0.17,0.21,0.22))
    _make_box("LeftWall", Vector3(-17,2,0), Vector3(0.5,4,38), Color(0.15,0.18,0.19))
    _make_box("RightWall", Vector3(17,2,0), Vector3(0.5,4,38), Color(0.15,0.18,0.19))
    _make_box("FrontLeftWall", Vector3(-12,2,18), Vector3(10,4,0.5), Color(0.17,0.21,0.22))
    _make_box("FrontRightWall", Vector3(12,2,18), Vector3(10,4,0.5), Color(0.17,0.21,0.22))

    _make_station("ЛАРЁК С ЛИМОНАДОМ", Vector3(-7,0,-11), Color(0.82,0.65,0.17), "lemon")
    _make_station("ТЕРМИНАЛ ЗАКАЗОВ", Vector3(7,0,-11), Color(0.1,0.55,0.43), "terminal")
    _make_station("ИССЛЕДОВАТЕЛЬСКАЯ СТАНЦИЯ", Vector3(-12,0,-2), Color(0.25,0.56,0.72), "incubator")
    _make_station("АНАЛИЗАТОР", Vector3(-12,0,5), Color(0.48,0.43,0.75), "centrifuge")
    _make_station("КЛЕТКА", Vector3(12,0,1), Color(0.65,0.28,0.25), "cage")
    _make_station("ВЫХОД В ГОРОД", Vector3(0,0,-16), Color(0.55,0.22,0.2), "door")

    for i in range(7):
        _make_box("CeilingBeam%d" % i, Vector3(-14 + i*4.5, 3.8, 12), Vector3(0.18,0.2,35), Color(0.22,0.26,0.27))
    for i in range(5):
        _make_box("FloorStripe%d" % i, Vector3(-14+i*7, -0.03, 0), Vector3(0.045,0.02,34), Color(0.22,0.28,0.28))

func _make_box(label: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.82
    node.material_override = mat
    node.position = pos
    add_child(node)
    if size.y > 0.4 and label.find("Beam") == -1 and label.find("Stripe") == -1:
        var body := StaticBody3D.new()
        body.position = pos
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        shape.shape = box
        body.add_child(shape)
        add_child(body)
    return node

func _make_station(label: String, pos: Vector3, color: Color, id: String) -> void:
    _make_box(id+"_base", pos + Vector3(0,0.55,0), Vector3(2.4,1.1,1.5), color.darkened(0.25))
    _make_box(id+"_top", pos + Vector3(0,1.15,0), Vector3(2.55,0.12,1.65), color.lightened(0.15))
    var label3d := Label3D.new()
    label3d.text = label
    label3d.font_size = 36
    label3d.pixel_size = 0.009
    label3d.position = pos + Vector3(0,2.2,0)
    label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label3d.modulate = Color(0.86,0.95,0.93)
    add_child(label3d)
    station_data.append({"id":id, "name":label, "pos":pos})

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0,0.2,9)
    add_child(player)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.7
    collision.shape = capsule
    collision.position.y = 0.85
    player.add_child(collision)
    camera = Camera3D.new()
    camera.position.y = 1.55
    camera.fov = 76
    player.add_child(camera)

func _build_ui() -> void:
    root_ui = CanvasLayer.new()
    add_child(root_ui)
    var bg := ColorRect.new()
    bg.color = Color(0.025,0.04,0.045,0.72)
    bg.position = Vector2(14,14)
    bg.size = Vector2(350,142)
    root_ui.add_child(bg)
    hud = VBoxContainer.new()
    hud.position = Vector2(28,23)
    hud.size = Vector2(325,125)
    root_ui.add_child(hud)
    stats_label = Label.new()
    stats_label.add_theme_font_size_override("font_size", 17)
    hud.add_child(stats_label)
    hint_label = Label.new()
    hint_label.add_theme_color_override("font_color", Color(0.5,0.95,0.72))
    hint_label.add_theme_font_size_override("font_size", 15)
    hud.add_child(hint_label)
    log_label = RichTextLabel.new()
    log_label.position = Vector2(14,166)
    log_label.size = Vector2(350,110)
    log_label.bbcode_enabled = true
    root_ui.add_child(log_label)
    crosshair = Label.new()
    crosshair.text = "+"
    crosshair.add_theme_font_size_override("font_size", 26)
    crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    crosshair.position = Vector2(-8,-17)
    root_ui.add_child(crosshair)
    interact_prompt = Label.new()
    interact_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    interact_prompt.position = Vector2(-170,-95)
    interact_prompt.size = Vector2(340,38)
    interact_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    interact_prompt.add_theme_font_size_override("font_size", 20)
    root_ui.add_child(interact_prompt)

    # Touch controls for Android builds
    var mobile_controls := Control.new()
    mobile_controls.name = "MobileControls"
    mobile_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_ui.add_child(mobile_controls)
    var pad := GridContainer.new()
    pad.columns = 3
    pad.position = Vector2(22, -190)
    pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    pad.add_theme_constant_override("h_separation", 8)
    pad.add_theme_constant_override("v_separation", 8)
    mobile_controls.add_child(pad)
    _add_touch_spacer(pad)
    _touch_button(pad, "▲", "forward")
    _add_touch_spacer(pad)
    _touch_button(pad, "◀", "left")
    _touch_button(pad, "▼", "backward")
    _touch_button(pad, "▶", "right")
    var look_area := Control.new()
    look_area.name = "TouchLookArea"
    look_area.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    look_area.position = Vector2(-360, -260)
    look_area.size = Vector2(340, 230)
    look_area.mouse_filter = Control.MOUSE_FILTER_STOP
    mobile_controls.add_child(look_area)
    look_area.gui_input.connect(_on_touch_look_input)
    var interact_button := Button.new()
    interact_button.text = "E\nДействие"
    interact_button.custom_minimum_size = Vector2(92, 64)
    interact_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    interact_button.position = Vector2(-118, -94)
    mobile_controls.add_child(interact_button)
    interact_button.pressed.connect(_try_interact)
    mobile_controls.visible = OS.has_feature("android") or OS.has_feature("ios")

    menu_layer = Control.new()
    menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_ui.add_child(menu_layer)
    panel_layer = Control.new()
    panel_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_ui.add_child(panel_layer)
    pause_layer = Control.new()
    pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_ui.add_child(pause_layer)

func _add_touch_spacer(parent: GridContainer) -> void:
    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(64, 58)
    parent.add_child(spacer)

func _touch_button(parent: GridContainer, label_text: String, direction: String) -> void:
    var b := Button.new()
    b.text = label_text
    b.custom_minimum_size = Vector2(64, 58)
    b.add_theme_font_size_override("font_size", 22)
    b.button_down.connect(func(): touch_move[direction] = true)
    b.button_up.connect(func(): touch_move[direction] = false)
    parent.add_child(b)

func _on_touch_look_input(event: InputEvent) -> void:
    if not started or paused or panel_layer.visible:
        return
    if event is InputEventScreenTouch:
        touch_look_active = event.pressed
        touch_look_last = event.position
    elif event is InputEventScreenDrag and touch_look_active:
        var delta := event.relative
        player.rotate_y(-delta.x * 0.004)
        pitch = clamp(pitch - delta.y * 0.004, -1.25, 1.25)
        camera.rotation.x = pitch

func _make_overlay(parent: Control, title_text: String, subtitle: String = "") -> VBoxContainer:
    var dim := ColorRect.new()
    dim.color = Color(0.01,0.025,0.03,0.92)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    parent.add_child(dim)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    parent.add_child(center)
    var box := VBoxContainer.new()
    box.custom_minimum_size = Vector2(480, 400)
    box.add_theme_constant_override("separation", 12)
    center.add_child(box)
    var title := Label.new()
    title.text = title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", Color(0.63,0.94,0.79))
    box.add_child(title)
    if subtitle != "":
        var sub := Label.new()
        sub.text = subtitle
        sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(sub)
    return box

func _button(parent: Node, text: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(300,42)
    b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

func _show_main_menu() -> void:
    _clear_children(menu_layer)
    _clear_children(panel_layer)
    _clear_children(pause_layer)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var box := _make_overlay(menu_layer, "СИМУЛЯТОР СОЗДАНИЯ ЧУМЫ", "3D-версия для Windows • сохранения в 3 слота")
    var slot_label := Label.new()
    slot_label.text = "Выбери сохранение:"
    slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(slot_label)
    slot_option = OptionButton.new()
    slot_option.custom_minimum_size = Vector2(300,40)
    for i in range(3):
        slot_option.add_item(_slot_title(i+1), i)
    slot_option.select(0)
    box.add_child(slot_option)
    _button(box, "▶ Продолжить", func(): _start_game(false))
    _button(box, "＋ Новая игра", func(): _start_game(true))
    _button(box, "Выйти", func(): get_tree().quit())
    _button(box, "Управление: WASD • мышь • E • Esc", func(): _show_main_menu())
    menu_layer.visible = true
    panel_layer.visible = false
    pause_layer.visible = false

func _slot_title(slot: int) -> String:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATHS[slot-1]) == OK and cfg.has_section("game"):
        return "Сохранение %d — есть прогресс" % slot
    return "Сохранение %d — пусто" % slot

func _start_game(new_game: bool) -> void:
    selected_slot = slot_option.get_selected_id() + 1
    if new_game:
        _fresh_state()
        _save_game()
    else:
        if not _load_game():
            _notify("В этом слоте нет сохранения. Нажми «Новая игра».")
            return
    started = true
    paused = false
    menu_layer.visible = false
    pause_layer.visible = false
    panel_layer.visible = false
    player.position = Vector3(0,0.2,9)
    player.rotation = Vector3.ZERO
    pitch = 0
    if not (OS.has_feature("android") or OS.has_feature("ios")):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _refresh_hud()

func _show_pause() -> void:
    if not started:
        _show_main_menu()
        return
    paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _clear_children(pause_layer)
    var box := _make_overlay(pause_layer, "ПАУЗА", "Сохранение %d" % selected_slot)
    _button(box, "▶ Продолжить", func():
        paused = false
        _clear_children(pause_layer)
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    )
    _button(box, "💾 Сохранить и в меню сохранений", func():
        _save_game()
        started = false
        paused = false
        _show_main_menu()
    )
    _button(box, "Сохранить сейчас", func():
        _save_game()
        _notify("Прогресс сохранён.")
    )
    pause_layer.visible = true
    menu_layer.visible = false
    panel_layer.visible = false

func _clear_children(node: Node) -> void:
    for child in node.get_children():
        child.queue_free()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and started and not paused and panel_layer.visible == false:
        player.rotate_y(-event.relative.x * 0.0025)
        pitch = clamp(pitch - event.relative.y * 0.0025, -1.25, 1.25)
        camera.rotation.x = pitch
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if panel_layer.visible:
                panel_layer.visible = false
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            elif started and not paused:
                _show_pause()
            elif paused:
                _clear_children(pause_layer)
                pause_layer.visible = false
                paused = false
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        elif event.keycode == KEY_E and started and not paused and not panel_layer.visible:
            _try_interact()

func _physics_process(delta: float) -> void:
    if not started or paused or panel_layer.visible:
        player.velocity = Vector3.ZERO
        return
    var dir := Vector3.ZERO
    if Input.is_action_pressed("move_forward") or touch_move.forward:
        dir -= player.global_transform.basis.z
    if Input.is_action_pressed("move_backward") or touch_move.backward:
        dir += player.global_transform.basis.z
    if Input.is_action_pressed("move_left") or touch_move.left:
        dir -= player.global_transform.basis.x
    if Input.is_action_pressed("move_right") or touch_move.right:
        dir += player.global_transform.basis.x
    dir.y = 0
    dir = dir.normalized()
    player.velocity.x = dir.x * 5.0
    player.velocity.z = dir.z * 5.0
    player.velocity.y -= 18.0 * delta
    player.move_and_slide()

func _process(delta: float) -> void:
    if message_timer > 0:
        message_timer -= delta
        if message_timer <= 0:
            message_text = "Подойди к объекту и нажми E"
    if started and not paused:
        elapsed += delta
        day_timer += delta
        delivery_timer += delta
        auto_timer += delta
        if day_timer >= 45:
            day_timer = 0
            state.day += 1
            state.heat = max(0.0, float(state.heat)-3.0)
        if delivery_timer >= 1.0:
            delivery_timer = 0
            _tick_deliveries()
        if bool(state.upg.get("autom", false)) and auto_timer >= 2:
            auto_timer = 0
            state.money += 13
            _log("🤖 Автоматизация принесла $13")
        if int(state.get("cups",0)) > 0:
            pass
        _refresh_hud()
        if int(state.pop) <= 0 and not bool(state.over):
            state.over = true
            state.win = true
            _notify("Победа! Игровой сценарий завершён.")
    _update_prompt()

func _nearest_station() -> Dictionary:
    var best: Dictionary = {}
    var best_dist := 999.0
    for station in station_data:
        var d: float = player.global_position.distance_to(station.pos)
        if d < best_dist:
            best_dist = d
            best = station
    if best_dist <= 3.8:
        return best
    return {}

func _update_prompt() -> void:
    if not started or paused or panel_layer.visible:
        interact_prompt.text = ""
        return
    var s := _nearest_station()
    if s.is_empty():
        interact_prompt.text = ""
    else:
        interact_prompt.text = "[E] " + s.name
    if message_timer > 0:
        hint_label.text = message_text

func _try_interact() -> void:
    var s := _nearest_station()
    if s.is_empty():
        _notify("Подойди ближе к объекту.")
        return
    _open_station(str(s.id))

func _open_station(id: String) -> void:
    panel_name = id
    _clear_children(panel_layer)
    var box := _make_overlay(panel_layer, _station_title(id), "День %d • Слот %d" % [state.day, selected_slot])
    match id:
        "lemon":
            _button(box, "Выжать лимон (нужно 1)", func(): _squeeze())
            _button(box, "Продать стаканы (+$5 за стакан)", func(): _sell_cup())
            _button(box, "Назад", func(): _close_panel())
        "terminal":
            var scroll := ScrollContainer.new()
            scroll.custom_minimum_size = Vector2(620,460)
            box.add_child(scroll)
            var list := VBoxContainer.new()
            list.custom_minimum_size.x = 580
            scroll.add_child(list)
            for item in ITEMS:
                var owned := bool(state.upg.get(item.id,false)) if item.get("once",false) else false
                var inv_count := int(state.inv.get(item.id,0))
                var row := HBoxContainer.new()
                list.add_child(row)
                var lbl := Label.new()
                lbl.text = "%s\n$%d • %s" % [item.name, item.price, item.desc]
                lbl.custom_minimum_size = Vector2(400,58)
                lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                row.add_child(lbl)
                var btn := Button.new()
                btn.text = "Куплено" if owned else "Заказать"
                btn.custom_minimum_size = Vector2(120,46)
                btn.disabled = owned or _is_delivering(item.id) or int(state.money) < int(item.price)
                var item_id: String = item.id
                btn.pressed.connect(func(): _buy_item(item_id))
                row.add_child(btn)
            _button(box, "Назад", func(): _close_panel())
        "incubator":
            _button(box, "Начать исследование (1 набор)", func(): _start_research())
            _button(box, "Назад", func(): _close_panel())
        "centrifuge":
            _button(box, "Анализировать образец", func(): _analyse())
            _button(box, "Назад", func(): _close_panel())
        "cage":
            _button(box, "Провести игровой эксперимент", func(): _experiment())
            _button(box, "Выпустить крыс в город", func(): _release_rats())
            _button(box, "Назад", func(): _close_panel())
        "door":
            _button(box, "Выпустить крыс в город", func(): _release_rats())
            _button(box, "Назад", func(): _close_panel())
    panel_layer.visible = true
    menu_layer.visible = false
    pause_layer.visible = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _station_title(id: String) -> String:
    match id:
        "lemon": return "ЛАРЁК С ЛИМОНАДОМ"
        "terminal": return "ТЕРМИНАЛ ЗАКАЗОВ"
        "incubator": return "ИССЛЕДОВАТЕЛЬСКАЯ СТАНЦИЯ"
        "centrifuge": return "АНАЛИЗАТОР ОБРАЗЦОВ"
        "cage": return "КЛЕТКА"
        _: return "ВЫХОД В ГОРОД"

func _close_panel() -> void:
    panel_layer.visible = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _refresh_hud()

func _squeeze() -> void:
    if int(state.inv.lemon) < 1:
        _notify("Нет лимонов. Закажи лимон в терминале.")
    elif int(state.cups) > 0:
        _notify("Банка уже полная.")
    else:
        state.inv.lemon -= 1
        state.cups = 3
        _log("🍋 Лимон выжат — 3 стакана")
    _open_station("lemon")

func _sell_cup() -> void:
    if int(state.cups) < 1:
        _notify("Сначала выжми лимон.")
    else:
        state.cups -= 1
        state.money += 5
        _log("🥤 Продан стакан лимонада: +$5")
    _open_station("lemon")

func _buy_item(id: String) -> void:
    var item: Dictionary = {}
    for it in ITEMS:
        if it.id == id:
            item = it
            break
    if item.is_empty():
        return
    if bool(item.get("once",false)) and bool(state.upg.get(id,false)):
        _notify("Уже куплено.")
        return
    if _is_delivering(id):
        _notify("Заказ уже в пути.")
        return
    if int(state.money) < int(item.price):
        _notify("Не хватает денег.")
        return
    state.money -= int(item.price)
    state.heat = min(100.0, float(state.heat) + clamp(float(item.price)/15.0,1.0,10.0))
    deliveries.append({"id":id,"remaining":int(item.time)})
    _log("📦 Заказ: %s — $%d" % [item.name,item.price])
    _open_station("terminal")

func _is_delivering(id: String) -> bool:
    for d in deliveries:
        if d.id == id:
            return true
    return false

func _tick_deliveries() -> void:
    for i in range(deliveries.size()-1,-1,-1):
        deliveries[i].remaining -= 1
        if deliveries[i].remaining <= 0:
            var id: String = deliveries[i].id
            deliveries.remove_at(i)
            _deliver(id)

func _deliver(id: String) -> void:
    var item: Dictionary = {}
    for it in ITEMS:
        if it.id == id:
            item = it
            break
    if item.is_empty():
        return
    if bool(item.get("once",false)):
        state.upg[id] = true
    else:
        state.inv[id] = int(state.inv.get(id,0)) + 1
    _log("✅ Доставлено: " + item.name)

func _start_research() -> void:
    if not state.upg.get("incubator",false):
        _notify("Сначала открой исследовательскую станцию в терминале.")
    elif not state.upg.get("strain",false):
        _notify("Сначала приобрети игровой образец штамма.")
    elif int(state.inv.culture) < 1:
        _notify("Нет исследовательского набора.")
    elif bool(state.inc):
        _notify("Исследование уже идёт.")
    else:
        state.inv.culture -= 1
        state.inc = true
        _log("🔬 Исследование запущено.")
        get_tree().create_timer(5.0).timeout.connect(func():
            if is_instance_valid(self) and bool(state.inc):
                state.inc = false
                state.raw = int(state.raw) + (5 if state.upg.get("reactor",false) else 1)
                _log("🔬 Исследование завершено: образец готов к анализу.")
        )
    _open_station("incubator")

func _analyse() -> void:
    if not state.upg.get("centrifuge",false):
        _notify("Сначала открой анализатор в терминале.")
    elif int(state.raw) < 1:
        _notify("Нет образца для анализа.")
    else:
        state.raw -= 1
        state.pure = int(state.pure) + 1
        state.strain_level = int(state.strain_level) + 1
        _log("⚗️ Анализ завершён. Уровень игрового штамма: %d" % state.strain_level)
    _open_station("centrifuge")

func _experiment() -> void:
    if int(state.pure) < 1:
        _notify("Нужен исследованный образец.")
    elif int(state.inv.rat) < 1:
        _notify("Нужна лабораторная крыса.")
    elif int(state.inv.syringe) < 1 and not state.upg.get("injector",false):
        _notify("Нужен медицинский набор.")
    else:
        state.pure -= 1
        state.inv.rat -= 1
        if not state.upg.get("injector",false):
            state.inv.syringe -= 1
        var chance := 0.65 if int(state.inv.immuno) == 0 else 0.95
        if state.upg.get("injector",false):
            chance = 1.0
        if randf() <= chance:
            state.infected = int(state.infected) + 1
            state.strain_level = int(state.strain_level) + 1
            _log("🐀 Игровой эксперимент успешен. Носителей: %d" % state.infected)
        else:
            state.leak = min(100.0,float(state.leak)+7.0)
            _log("💥 Эксперимент не удался.")
    _open_station("cage")

func _release_rats() -> void:
    if int(state.infected) < 1:
        _notify("Нет игровых носителей.")
    else:
        var n := int(state.infected)
        var power := 1 + int(state.strain_level)
        if state.upg.get("fleas",false): power *= 3
        for id in ["mut1","mut2","mut3"]:
            if state.upg.get(id,false): power *= 10
        var deaths := min(float(n*power),float(state.pop))
        state.pop = max(0.0,float(state.pop)-deaths)
        state.killed = float(state.killed)+deaths
        state.infected = 0
        state.door_open = true
        if state.upg.get("aerosol",false):
            state.pop = max(0.0,float(state.pop)-deaths*0.5)
            _log("🚪 Запущен цепной сценарий! Условная численность населения снижается.")
        else:
            _log("🚪 Выпущено носителей: %d. Изменение населения: %s" % [n,_format_number(deaths)])
        if float(state.pop) <= 0:
            state.win = true
            state.over = true
            _notify("Победа! Сценарий завершён.")
    _open_station("door")

func _format_number(n: float) -> String:
    if n >= 1000000000.0: return "%.2f млрд" % (n/1000000000.0)
    if n >= 1000000.0: return "%.2f млн" % (n/1000000.0)
    if n >= 1000.0: return "%.1f тыс." % (n/1000.0)
    return str(int(n))

func _refresh_hud() -> void:
    if not is_instance_valid(stats_label):
        return
    stats_label.text = "День: %d\nДеньги: $%s   Население: %s\nЛимоны: %d  Стаканы: %d\nНаборы: %d  Крысы: %d  Носители: %d" % [
        int(state.get("day",1)), str(int(state.get("money",15))), _format_number(float(state.get("pop",8000000000.0))),
        int(state.get("inv",{}).get("lemon",0)), int(state.get("cups",0)),
        int(state.get("inv",{}).get("culture",0)), int(state.get("inv",{}).get("rat",0)), int(state.get("infected",0))
    ]
    hint_label.text = message_text
    var logs: Array = state.get("log",[])
    log_label.clear()
    for i in range(max(0,logs.size()-5),logs.size()):
        log_label.append_text(str(logs[i]) + "\n")

func _log(text: String) -> void:
    var logs: Array = state.get("log",[])
    logs.append(text)
    while logs.size() > 12:
        logs.pop_front()
    state.log = logs
    _refresh_hud()

func _notify(text: String) -> void:
    message_text = text
    message_timer = 3.5
    hint_label.text = text

func _save_game() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("game","state",state)
    cfg.set_value("game","deliveries",deliveries)
    cfg.set_value("game","saved_at",Time.get_datetime_string_from_system())
    cfg.save(SAVE_PATHS[selected_slot-1])

func _load_game() -> bool:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATHS[selected_slot-1]) != OK:
        return false
    var loaded: Variant = cfg.get_value("game","state",{})
    if not loaded is Dictionary or loaded.is_empty():
        return false
    state = loaded
    deliveries = cfg.get_value("game","deliveries",[])
    return true

func _exit_tree() -> void:
    if started and not state.is_empty():
        _save_game()
