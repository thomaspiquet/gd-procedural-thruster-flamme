# MIT License
# Copyright (c) 2023, Thomas Piquet

extends Resource
class_name FlammeSource

# Position of the source on the texture
@export var position: Vector2i = Vector2i.ZERO
# flag source for lateral process (set to false to reduce compute time)
@export var markForLaterals: bool = true
