class_name StageSpawnData
extends Resource
# A bounded trickle of one special enemy role during part of a stage.

@export var enemy_id: StringName
@export var start_time := 30.0
@export var end_time := 300.0
@export var interval := 20.0
@export var max_alive := 2
