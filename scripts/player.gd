@tool
extends Node
class_name Player

var cards : Array[CardResource]
var deck : Array[Card]
var hand : Array[Card]
var discard_pile : Array[Card]
var terrain : Array[Card]

var starting_mana := 3
var max_mana := 3
var current_mana := 0
var mana_increment_per_turn := 1
var max_hp := 20
var current_hp := 20
var card_draw := 7

var card_controls : Dictionary[String, CardControl]

@export var main: Main

@export var hand_control: HBoxContainer
@export var terrain_control: HBoxContainer
@export var hp_label: Label
const CARD = preload("res://scenes/card.tscn")

func clear_visuals():
	for cc in card_controls.values():
		cc.queue_free()
	card_controls.clear()

func start_game():
	deck.clear()
	hand.clear()
	terrain.clear()
	discard_pile.clear()
	for cr in cards:
		var nc = Card.new()
		nc.load_resource(cr)
		deck.append(nc)
	deck.shuffle()
	
	max_mana = starting_mana
	current_hp = max_hp
	await draw(7)
	
func start_turn():
	current_mana = max_mana
	await draw(1)
	for card in terrain: 
		card.can_attack = true

func draw(count):
	for i in count:
		if deck.size() <= 0: break
		if main.visualize:
			var ncc = CARD.instantiate() as CardControl
			ncc.load_card(deck[0])
			hand_control.add_child(ncc)
			ncc.owner = EditorInterface.get_edited_scene_root()
			card_controls[deck[0].name] = ncc
			await main.wait(0.1)
			
		hand.append(deck[0])
		deck.erase(deck[0])
			

func end_turn():
	max_mana += mana_increment_per_turn

func show_deck():
	cards.sort_custom(func(a, b): return a.atk < b.atk)
	cards.sort_custom(func(a, b): return a.cost < b.cost)
	var str = ""
	for c in cards:
		str = str(str, " ", c.cost)
	print(str)
	str = ""
	for c in cards:
		str = str(str, " ", c.atk)
	print(str)
	str = ""
	for c in cards:
		str = str(str, " ", c.def)
	print(str)
		
func show_card_costs():
	print("Card cost repartition")
	var cost = 0
	var cost_str = ""
	var cost_count = {}
	
	for c in cards:
		if not cost_count.has(c.cost): cost_count[c.cost] = 0
		cost_count[c.cost] += 1
		
	for k in cost_count.keys():
		cost_str = ""
		for i in cost_count[k]:
			cost_str = str(cost_str, "#")
		print(k, " x ", cost_count[k], " ", cost_str)

func save_deck():
	print("SAVED DECK")
	var save = []
	for c in cards:
		save.append(str(c.cost, "_", c.atk, "_", c.def))
	return "\n".join(save)
	
func get_playable_cards():
	return hand.filter(func(c): return c.cost <= current_mana)
	
func play_costest_card():
	var playable_cards = get_playable_cards()
	if not playable_cards.size(): return false
	playable_cards.sort_custom(func(a, b): return a.cost > b.cost)
	play_card(playable_cards[0])
	return true
	
func play_card(card: Card):
	hand.erase(card)
	terrain.append(card)
	current_mana -= card.cost
	if main.visualize:
		card_controls[card.name].reparent(terrain_control)

func take_damage(value):
	current_hp -= value
	if main.visualize:
		hp_label.text = str(current_hp, "/", max_hp, " HP")

func is_alive():
	return current_hp > 0

class Card:
	var atk := 0
	var def := 0
	var cost := 0
	var can_attack := false
	var name: String
	func load_resource(cr: CardResource):
		atk = cr.atk
		def = cr.def
		cost = cr.cost
		name = cr.resource_name
