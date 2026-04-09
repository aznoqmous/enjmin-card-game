extends Resource
class_name CardResource

var cost : int :
	get():
		return floor(
			float(atk + def) / 2.0 
			+ (2.0 if has_guard else 0.0)
			+ (1.0 if has_flying else 0.0)
			+ (2.0 if has_charge else 0.0)
		)

@export var atk : int
@export var def : int

@export var has_guard := false
@export var has_flying := false
@export var has_charge := false

func get_id():
	return str(cost, "_", atk, "_", def, "_", 1 if has_guard else 0, "_", 1 if has_flying else 0, "_", 1 if has_charge else 0)
