class_name StageEventData
extends Resource
# A scheduled beat in a stage: fires once when the stage clock passes time.

@export var id: StringName
@export var time := 0.0
@export var banner := ""
@export var duration := 30.0
