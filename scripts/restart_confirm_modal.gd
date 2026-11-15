extends Control
class_name RestartConfirmModal

signal confirmed
signal canceled

@onready var scrim: ColorRect = $Scrim if has_node("Scrim") else null
@onready var card: PanelContainer = $Center/Card if has_node("Center/Card") else null
@onready var title_label: Label = find_child("TitleLabel", true, false) as Label
@onready var message_label: Label = find_child("MessageLabel", true, false) as Label
@onready var cancel_button: Button = find_child("CancelButton", true, false) as Button
@onready var ok_button: Button = find_child("RestartButton", true, false) as Button

var title_text: String = "RESTART LEVEL":
	set(v):
		title_text = v
		if title_label:
			title_label.text = v

var dialog_text: String = "":
	set(v):
		dialog_text = v
		if message_label:
			message_label.text = v

var ok_button_text: String = "RESTART":
	set(v):
		ok_button_text = v
		if ok_button:
			ok_button.text = v

var cancel_button_text: String = "CANCEL":
	set(v):
		cancel_button_text = v
		if cancel_button:
			cancel_button.text = v

var _pop_tween: Tween = null


func _ready() -> void:
	# Keep hidden initially
	visible = false

	if title_label and not title_text.is_empty():
		title_label.text = title_text
	if message_label and not dialog_text.is_empty():
		message_label.text = dialog_text
	if ok_button and not ok_button_text.is_empty():
		ok_button.text = ok_button_text
	if cancel_button and not cancel_button_text.is_empty():
		cancel_button.text = cancel_button_text

	if ok_button and not ok_button.pressed.is_connected(_on_ok_pressed):
		ok_button.pressed.connect(_on_ok_pressed)
		_attach_spring_physics(ok_button)

	if cancel_button and not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)
		_attach_spring_physics(cancel_button)

	if scrim and not scrim.gui_input.is_connected(_on_scrim_gui_input):
		scrim.gui_input.connect(_on_scrim_gui_input)


func popup_centered() -> void:
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()

	visible = true

	if scrim:
		scrim.modulate.a = 0.0

	if card:
		card.modulate.a = 0.0
		# Reset pivot to center for pop scaling
		var sz: Vector2 = card.size
		if sz == Vector2.ZERO and card.custom_minimum_size != Vector2.ZERO:
			sz = card.custom_minimum_size
		card.pivot_offset = sz / 2.0
		card.scale = Vector2(0.86, 0.86)

	_pop_tween = create_tween().set_parallel(true)
	if scrim:
		_pop_tween.tween_property(scrim, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if card:
		_pop_tween.tween_property(card, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_pop_tween.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_modal() -> void:
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()

	_pop_tween = create_tween().set_parallel(true)
	if scrim:
		_pop_tween.tween_property(scrim, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if card:
		_pop_tween.tween_property(card, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_pop_tween.tween_property(card, "scale", Vector2(0.92, 0.92), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pop_tween.finished.connect(func():
		visible = false
	, CONNECT_ONE_SHOT)


func _on_ok_pressed() -> void:
	hide_modal()
	confirmed.emit()


func _on_cancel_pressed() -> void:
	hide_modal()
	canceled.emit()


func _on_scrim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		_on_cancel_pressed()
	elif event is InputEventScreenTouch and event.is_pressed():
		_on_cancel_pressed()


func get_ok_button() -> Button:
	return ok_button


func get_cancel_button() -> Button:
	return cancel_button


func get_label() -> Label:
	return message_label


func _attach_spring_physics(btn: Button) -> void:
	if btn == null or btn.has_meta("has_spring_physics"):
		return
	btn.set_meta("has_spring_physics", true)
	var calc_pivot: Callable = func() -> void:
		var sz: Vector2 = btn.custom_minimum_size if btn.size == Vector2.ZERO else btn.size
		btn.pivot_offset = sz / 2.0
	calc_pivot.call()
	btn.button_down.connect(func():
		calc_pivot.call()
		var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.06)
	)
	var restore: Callable = func():
		var tw: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.25)
	btn.button_up.connect(restore)
	btn.mouse_exited.connect(restore)

