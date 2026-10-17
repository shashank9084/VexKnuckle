@tool
extends Control
class_name Joystick



func _ready() -> void:
	VJDXRenderer.draw_joystick(
		self,
		Vector2(150, 400),  # Center
		100.0,              # Base radius
		Vector2(170, 380),  # Thumb position
		30.0,               # Thumb radius
		false,             # Is pressed?
		null,
		null,
		null,
		Color.BLACK,
		Color.BLACK,
		Color.BLACK,
		Color.BLACK
	)
