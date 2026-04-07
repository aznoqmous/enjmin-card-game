extends Resource
class_name CardResource

var cost : int :
	get():
		return floor((atk + def) / 2.0)

@export var atk : int
@export var def : int
