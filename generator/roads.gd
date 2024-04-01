extends Node2D

var centres = []
var roads = [] #Primaarsete teede loend
var secondary_roads = [] # Sekundaarsete teede loend
var houses = []
var houses_variants = []
var max_house_size = 100
var min_house_size = 20
var distances = []
var max_points = 7
var noise_scale = 0.1
var map_width = 600
var map_height = 600
var angle_threshold = 90 # Nurk, millest väiksemate nurkade all sekundaarsete teede ristumine ei ole lubatud

# Set L-system parameters
var axiom = "F"
var max_iterations = 4
var min_angle = 60
var angle = 90
var length = 200.0
var rules = [
	Rule.new("F", "FF+[+F-F-F]-[-F+F+F]")
]



func _ready():
	generate_centres()
	connect_centres()
	#generate_secondary_roads()
	



func find_closest_centres(origin_centre):
	distances.clear()
	for centre in centres:
		if centre != origin_centre:
			var distance = origin_centre.distance_to(centre)
			distances.append({"centre": centre, "distance": distance})
	
	distances.sort_custom(func (a, b): return a["distance"] < b["distance"])		
	return [distances[0]["centre"], distances[1]["centre"], distances[2]["centre"]]



func is_intersecting(a, b, c, d):
	var i = (b - a).cross(c - a)
	var j = (b - a).cross(d - a)
	if i == 0 or j == 0 or i * j > 0:
		return false
	i = (d - c).cross(a - c)
	j = (d - c).cross(b - c)
	return i != 0 and j != 0 and i * j <= 0



func generate_centres2():
	var rng = RandomNumberGenerator.new()
	rng.randomize() # Seadistab RNG algse oleku

	var min_distance= 200.0

	for i in range(max_points):
		var angle = deg_to_rad(rng.randf_range(0.0, 360.0)) # Juhuslik nurk
		var distance = rng.randf_range(min_distance, min_distance * 2.0) # Juhuslik kaugus
		var centre = Vector2(cos(angle), sin(angle)) * distance
		centres.append(centre)

# Nüüd on 'centres' massiivis pseudo-juhuslikult paigutatud Vector2 punktid


func generate_centres():
	var perlin_noise := FastNoiseLite.new()
	perlin_noise.set_noise_type(FastNoiseLite.NoiseType.TYPE_PERLIN)
	perlin_noise.set_frequency(0.1)
	
	var generation_index = 0
	while generation_index < max_points:
		var x := randf_range(0, map_width)
		var y := randf_range(0, map_height)
		var noise_value := perlin_noise.get_noise_2d(x * noise_scale, y * noise_scale)
		var previous_centre = Vector2.ZERO
		var min_spacing := 400
		if abs(noise_value) > 0.09:
			var centre := Vector2(x, y)
			
			if previous_centre == Vector2.ZERO or centre.distance_to(previous_centre) > min_spacing:
				centres.append(centre)
				generation_index += 1



func connect_centres():
	for i in range(len(centres)):
		var closest_centres = find_closest_centres(centres[i])
		for centre in closest_centres:
			var new_road = Line2D.new()
			new_road.width = 5
			new_road.add_point(centres[i])
			new_road.add_point(centre)
			#print("Tee otspunktide koordinaadid on: ", new_road.points)
			#print("Tee keskpunt on: ",find_middle_point(centres[i], centre))
			
			if new_road.points.size() >= 2:
				var intersecting = false
				for road in roads:
					if road != new_road and road.points.size() >= 2 and is_intersecting(new_road.points[0], new_road.points[1], road.points[0], road.points[1]):
						intersecting = true
						break
				if not intersecting:
					self.add_child(new_road)
					roads.append(new_road)
		
	#modify_roads()



func modify_roads():
	for road in roads:
		var line_curve = road.curve
		var points_list = road.curve.get_baked_points()
		var new_points = PackedVector2Array()
		
		for i in range(points_list.size()):
			var point = points_list[i]
			var noise = randf_range(-10, 10) # Juhuslik müra
			var new_point = point.linear_interpolate(Vector2(point.x + noise, point.y + noise), 0.1)
			new_points.append(new_point)
		
		road.curve.clear_points()
		
		for new_point in new_points:
			road.curve.add_point(new_point)
			


func generate_secondary_roads():
	for centre in centres:
		var lsystem_string = generate_lsystem_string(axiom, rules, max_iterations)
		draw_lsystem_string_with_houses(lsystem_string, centre)



# Define an L-system rule
class Rule:
	var predecessor
	var successor

	func _init(pre, suc):
		predecessor = pre
		successor = suc



# Generate L-system string
func generate_lsystem_string(axiom, rules, iterations):	
	var result = axiom
	for i in range(iterations):
		var new_result = ""
		for char in result:
			var found_rule = false
			for rule in rules:
				if char == rule.predecessor:
					new_result += rule.successor
					found_rule = true
					break
			if not found_rule:
				new_result += char
		result = new_result
	
	return result



# Draw L-system string
func draw_lsystem_string_with_houses(lsystem_string, position):
	for centre in centres:
		for branching in range(4):
			var direction = Vector2(randf(), randf()).normalized()
			var stack = []
			for char in lsystem_string:
				if char == "F":
					var new_position = position + direction * length
					var path = Line2D.new()
					path.add_point(position)
					path.add_point(new_position)
					if is_valid_road(path):
						add_child(path) # Lisatakse tee otse klassi juurde
						secondary_roads.append(path)
						var start_point = path.get_point_position(0)
						var end_point = path.get_point_position(1)
						# Paigutab suvalise maja tee äärde
						for i in range(len(houses_types())):
							var road_direction = (end_point - start_point).normalized()
							var house_position = start_point + road_direction * find_middle_point((path.points[0]), (path.points[0]) - start_point)
							add_child(houses_variants[i]["house"])
							houses.append(houses_variants[i]["house"])
					position = new_position
				elif char == "+":
					direction = direction.rotated(deg_to_rad(+(randi_range(min_angle, angle))))
				elif char == "-":
					direction = direction.rotated(deg_to_rad(-(randi_range(min_angle, angle))))
				elif char == "[":
					stack.append(position)
					stack.append(direction)
				elif char == "]":
					direction = stack.pop_back()
					position = stack.pop_back()



func is_valid_road(road):
	for other_road in secondary_roads:
		if other_road != road and is_intersecting(other_road.points[0], other_road.points[1], road.points[0], road.points[1]):
			var angle = other_road.global_position.angle_to(road.global_position)
			if abs(angle) < deg_to_rad(angle_threshold):
				return false
	return true
 
func find_middle_point(point1, point2):
	var d_x = abs(abs(point1.x) - abs(point2.x))
	var d_y = abs(abs(point1.y) - abs(point2.y))
	var x_k = 0
	var y_k = 0	
	
	if point1.x <= point2.x:
		x_k = point1.x + d_x/2
	else: 
		x_k = point2.x + d_x/2
		
	if point1.y <= point2.y:
		y_k = point1.y + d_y/2
	else: 
		y_k = point2.y + d_y/2
	
	return Vector2(x_k, y_k)

func houses_types():
	var type_counter = 0
	var smallest_house = Polygon2D.new()
	smallest_house.polygon = [
				Vector2(-min_house_size / 2, -min_house_size / 2),
				Vector2(min_house_size / 2, -min_house_size / 2),
				Vector2(min_house_size / 2, min_house_size / 2),
				Vector2(-min_house_size / 2, min_house_size / 2)
			]
	houses_variants.append(smallest_house)
	var biggest_house = Polygon2D.new()
	biggest_house.polygon = [
				Vector2(-max_house_size / 2, -max_house_size / 2),
				Vector2(max_house_size / 2, -max_house_size / 2),
				Vector2(max_house_size / 2, max_house_size / 2),
				Vector2(-max_house_size / 2, max_house_size / 2)
	]
	houses_variants.append(biggest_house)
	for i in range(max_points - 1):
		var new_house = Polygon2D.new()
		var width = randi_range(20, max_house_size)
		type_counter += 1
		if type_counter % 2 == 0:
			var height = width
			new_house.polygon = [
				Vector2(-width / 2, -height / 2),
				Vector2(width / 2, -height / 2),
				Vector2(width / 2, height / 2),
				Vector2(-width / 2, height / 2)
			]
			var surface = width * height
			houses_variants.append({"house": new_house, "surface": surface})
		else:
			var height = randi_range(20, max_house_size)
			type_counter += 1
			new_house.polygon = [
				Vector2(-width / 2, -height / 2),
				Vector2(width / 2, -height / 2),
				Vector2(width / 2, height / 2),
				Vector2(width / 2, height / 2)
			]
			var surface = width * height
			houses_variants.append({"house": new_house, "surface": surface})
	houses_variants.sort_custom(func(a, b): return a["surface"] > b["surface"])
	return houses_variants
