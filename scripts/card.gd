@tool
extends Control
class_name CardControl

@export var cost_label: Label
@export var def_label: Label
@export var atk_label: Label
@export var name_label: Label

func load_card(card: Player.Card):
	cost_label.text = str(card.cost)
	def_label.text = str(card.def)
	atk_label.text = str(card.atk)
	name_label.text = str(card.name)
