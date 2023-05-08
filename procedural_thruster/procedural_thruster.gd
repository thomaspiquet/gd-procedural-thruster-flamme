# MIT License
# Copyright (c) 2023, Thomas Piquet

@tool
class_name ProceduralThruster
extends Node2D

# Size of the texture
@export var size: Vector2i = Vector2i(32, 32) :
	get:
		return size
	set(value):
		size = value
		onSizeChanged()

# Flamme sources
@export var sources: Array[FlammeSource]

# Temperature of the source pixels
@export var power: int = 120
# Random value in range added to power 
@export var random_power_range: Vector2i = Vector2i(-10, 10)
# Random value in range added to power of each sources
@export var random_power_range_per_source: Vector2i = Vector2i(-4, 4)

# Temperature lost for each pixel parsed by flamme initial flow
@export var cooling_flow: int = 10
# Temperature lost for each pixel parsed by flamme initial flow on ground
@export var cooling_flow_ground: int = 15
# Temperature lost for each pixel parsed by flamme laterals flow
@export var cooling_lateral: int = 25

# Override manually the maximum distance
@export var manual_distance: bool = false
# Distance to the virtual ground from the top of map (Processed with Raycast2D)
@export var distance: int = 32

# Number of frame per second wanted
@export var target_fps: int = 8

# Color Gradient of the flamme
@export var colors: Array[Color]

# Execution time in microseconds of the initial flow
@export var execution_time_flow: int
# Execution time in microseconds of the laterals
@export var execution_time_laterals: int
# Execution time in microseconds to render texture and set it to shader
@export var execution_time_texture: int 
# Execution time in microseconds of all the process
@export var execution_time_total: int

# Draw points map instead of final render
@export var must_draw_debug: bool = false
# Generate laterals
@export var must_generate_laterals: bool = true

# Image used to set pixels
var image: Image = null
# Random number generator for animation
var rng = RandomNumberGenerator.new()
# Temperature points, 2D map
var points: Array[int] = []
# Initial flow of the flamme
var initial_flow: Array[Vector2i] = []
# Real force after random
var current_max_force: int = 0
# Cumulative delta 
var cumulative: float = 0

func _process(delta):
	if (self.visible):
		self.cumulative += delta
		if (self.cumulative >= 1 / (float)(self.target_fps)):
			self.cumulative = 0
			
			var startTotal: int = Time.get_ticks_usec()
			
			if (!manual_distance):
				if $RayCast2D.is_colliding():
					var hit_point = $RayCast2D.get_collision_point()
					self.distance = (hit_point - $RayCast2D.global_position).length() / self.scale.y
				else:
					self.distance = size.y

			if (points.size() == 0):
				points.resize(size.x * size.y)
			
			# Reset arrays		
			points.fill(0)
			initial_flow.clear()
			
			# Adding some random power on top of base power
			self.current_max_force = power + rng.randi_range(random_power_range.x, random_power_range.y)
			
			var startFlow: int = Time.get_ticks_usec()
			
			for i in (sources.size()):
				if (sources[i] != null):
					# Adding some random power on top of previous generated power for each sources
					generate_flow(sources[i].position, Vector2i(0,1), self.current_max_force + rng.randi_range(random_power_range_per_source.x, random_power_range_per_source.y), sources[i].markForLaterals)
				
			
			execution_time_flow = Time.get_ticks_usec() - startFlow
			
			var startLaterals: int = Time.get_ticks_usec()
			
			if (must_generate_laterals):
				# Generate laterals
				for i in range(initial_flow.size()):
					generate_laterals(initial_flow[i], Vector2i(0,0), points[initial_flow[i].x + size.x * initial_flow[i].y])
			
			execution_time_laterals = Time.get_ticks_usec() - startLaterals
			
			var startTexture: int = Time.get_ticks_usec()
			
			# Generate Texture
			generate_texture()
			
			execution_time_texture = Time.get_ticks_usec() - startTexture
			
			execution_time_total = Time.get_ticks_usec() - startTotal

func generate_flow(position: Vector2i, direction: Vector2i, force: int, markForLaterals: bool) -> void:
	if (direction == Vector2i(0, 1)):
		force -= cooling_flow
	else:
		force -= cooling_flow_ground
		
	if (force <= 0 || position.x < 0 || position.y < 0 || position.x >= size.x || position.y >= size.y):
		return

	points[position.x + size.x * position.y] = force

	if (markForLaterals):
		var alreadyExist: bool = false
		for i in range(initial_flow.size()):
			if (initial_flow[i] == position):
				alreadyExist = true
				
		if (!alreadyExist):
			initial_flow.append(position)
		
	if ((position + direction).y > self.distance):
		generate_flow(position + Vector2i(-1, 0), Vector2i(-1, 0), force, markForLaterals)
		generate_flow(position + Vector2i(1, 0), Vector2i(1, 0), force, markForLaterals)
	else:
		generate_flow(position + direction, direction, force, markForLaterals)

func generate_laterals(position: Vector2i, direction: Vector2i, force: int) -> void:	
	if (force <= 0 || position.x < 0 || position.y < 0 || position.x >= size.x || position.y >= size.y):
		return
	
	if (direction != Vector2i(0, 0) && points[position.x + size.x * position.y] < force):
		points[position.x + size.x * position.y] = force
		
	force -= cooling_lateral
	
	# First iteration
	if (direction == Vector2i(0, 0)):
		generate_laterals(position + Vector2i(-1, 0), Vector2i(-1, 0), force)
		generate_laterals(position + Vector2i(1, 0), Vector2i(1, 0), force)
		generate_laterals(position + Vector2i(0, -1), Vector2i(0, -1), force)
		generate_laterals(position + Vector2i(0, 1), Vector2i(0, 1), force)
	# Next ones
	else:
		generate_laterals(position + direction, direction, force)		

func generate_texture() -> void:
	if (colors.size() < 1):
		return
	
	if (image == null):
		image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	
	var stepSize: int = self.current_max_force / colors.size()

	for iY in range(size.y):
		for iX in range(size.x):
			if (self.must_draw_debug):
				image.set_pixel(iX, iY, Color8(points[iX + size.x * iY],0,0,255))
			else:	
				if (points[iX + size.x * iY] > 0):
					if (points[iX + size.x * iY] / stepSize >= colors.size()):
						image.set_pixel(iX, iY, Color8(255, 255, 255, 255))
					else:
						image.set_pixel(iX, iY, colors[points[iX + size.x * iY] / stepSize])
				else:
					image.set_pixel(iX, iY, Color8(0, 0, 0, 0))
				
	var texture = ImageTexture.new()
	texture = texture.create_from_image(image)
	
	self.material.set_shader_parameter("input_texture", texture)

func onSizeChanged() -> void:
			points.resize(size.x * size.y)
			image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
						
			var texture = ImageTexture.new()
			texture = texture.create_from_image(image)
			
			self.texture = texture
		
			$RayCast2D.position = Vector2(0, -size.y / 2)
			$RayCast2D.target_position = Vector2(0, size.y) 
