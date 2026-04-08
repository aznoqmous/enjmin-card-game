@tool
extends Control
class_name CardControl

@export var background_texture: TextureRect
@export var cost_label: Label
@export var def_label: Label
@export var atk_label: Label
@export var name_label: Label

@export var guard_tex: TextureRect
@export var flying_tex: TextureRect
@export var charge_tex: TextureRect

func load_card(card: Player.Card):
	cost_label.text = str(card.cost)
	def_label.text = str(card.def)
	atk_label.text = str(card.atk)
	name_label.text = str(card.name)
	guard_tex.set_visible(card.has_guard)
	flying_tex.set_visible(card.has_flying)
	charge_tex.set_visible(card.has_charge)

func update_state(card: Player.Card):
	background_texture.modulate = Color.WHITE if card.can_attack else Color.DIM_GRAY

func update_playable(card: Player.Card, player: Player):
	background_texture.modulate = Color.WHITE if card.cost <= player.current_mana else Color.DIM_GRAY
