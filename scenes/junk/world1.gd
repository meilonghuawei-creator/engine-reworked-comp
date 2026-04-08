extends World

func _ready() -> void:
	super()

func _physics_process(delta: float) -> void:
	super(delta)

func _on_timer_timeout() -> void:
	$test.playing = !$test.playing
	pass # Replace with function body.
