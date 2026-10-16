extends RelicEffect
# Every EVERY gems collected become a soul shard.

const EVERY := 30

var gems := 0


func on_gem(_value: int) -> void:
	gems += 1
	if gems % EVERY == 0:
		gm().add_shards(1)
