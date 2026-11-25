extends CanvasLayer
## Shared HUD for score, lives and level status.

func update_state(_time: float, lives: int, score: int) -> void:
	$Lives.text = "Lives: %d" % lives
	$Score.text = "Score: %d" % score
