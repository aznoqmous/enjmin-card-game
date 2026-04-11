@tool
extends Node
class_name Player

var cards : Array[CardResource]
var deck_cards: Array[Card]
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
@export var mana_label: Label
@export var deck_label: Label
@export var portrait: TextureRect
const CARD = preload("res://scenes/card.tscn")

func _ready():
	for c in hand_control.get_children():
		c.queue_free()
	for c in terrain_control.get_children():
		c.queue_free()

func clear_visuals():
	for c in card_controls.values():
		if c: c.queue_free()
	card_controls.clear()
	await get_tree().process_frame
	
func update_deck_cards():
	deck_cards.clear()
	for cr in cards:
		var nc = Card.new()
		nc.load_resource(cr)
		deck_cards.append(nc)
		
func start_game():
	deck = deck_cards.duplicate()
	hand.clear()
	terrain.clear()
	discard_pile.clear()
	deck.shuffle()
	
	max_mana = starting_mana
	current_hp = max_hp
	await draw(7)
	
func start_turn():
	current_mana = max_mana
	for card in terrain: 
		card.can_attack = true
		if main.visualize:
			card_controls[card.name].update_state(card)
	if main.visualize:
		mana_label.text = str(current_mana, "/", max_mana)

func draw(count):
	for i in count:
		if deck.size() <= 0:
			take_damage(1)
			break
		if main.visualize:
			var ncc = CARD.instantiate() as CardControl
			ncc.load_card(deck[0])
			hand_control.add_child(ncc)
			#ncc.owner = EditorInterface.get_edited_scene_root()
			card_controls[deck[0].name] = ncc
			deck_label.text = str(deck.size(), "/", cards.size())
			await main.wait(0.1)
			
		hand.append(deck[0])
		deck.erase(deck[0])
	sort_hand()

func end_turn():
	max_mana += mana_increment_per_turn
	await draw(1)

func show_deck():
	cards.sort_custom(func(a, b): return a.atk < b.atk)
	cards.sort_custom(func(a, b): return a.cost < b.cost)
	var total = 0
	var str = "COST"
	for c in cards:
		str = str(str, " %2d" % c.cost)
		total += c.cost
	print(str, " | %3d" % total)
	total = 0
	str = "ATK "
	for c in cards:
		str = str(str, " %2d" % c.atk)
		total += c.atk
	print(str, " | %3d" % total)
	total = 0
	str = "DEF "
	for c in cards:
		str = str(str, " %2d" % c.def)
		total += c.def
	print(str, " | %3d" % total)
	total = 0
	str = "GURD"
	for c in cards:
		str = str(str, " %2d" % (1 if c.has_guard else 0))
		total += (1 if c.has_guard else 0)
	print(str, " | %3d" % total)
	total = 0
	str = "FLY "
	for c in cards:
		str = str(str, " %2d" % (1 if c.has_flying else 0))
		total += (1 if c.has_flying else 0)
	print(str, " | %3d" % total)
	total = 0
	str = "CHRG"
	for c in cards:
		str = str(str, " %2d" % (1 if c.has_charge else 0))
		total += (1 if c.has_charge else 0)
	print(str, " | %3d" % total)
		
func show_card_costs():
	print("Card cost repartition")
	var cost = 0
	var cost_str = ""
	var cost_count = {}
	
	for i in 8:
		cost_count[i] = 0
		
	for c in cards:
		cost_count[c.cost] += 1
		
	for k in cost_count.keys():
		cost_str = ""
		for i in cost_count[k]:
			cost_str = str(cost_str, "#")
		print(k, " x ", cost_count[k], " ", cost_str)

func get_card_costs():
	var cost = 0
	var cost_str = ""
	var cost_count = {}
	
	for i in 8:
		cost_count[i] = 0
		
	for c in cards:
		cost_count[c.cost] += 1
	return cost_count
	
func save_deck():
	var save = []
	for c in cards:
		save.append(c.get_id())
	return "\n".join(save)
	
func get_playable_cards():
	return hand.filter(func(c): return c.cost <= current_mana)
	
func play_costest_card():
	for card in hand:
		if card.cost <= current_mana:
			play_card(card)
			return true;
	return false

func sort_hand():
	hand.sort_custom(func(a, b): return a.cost > b.cost)
	
func play_card(card: Card):
	hand.erase(card)
	terrain.append(card)
	current_mana -= card.cost
	if main.visualize:
		card_controls[card.name].reparent(terrain_control)
		card_controls[card.name].update_state(card)
		mana_label.text = str(current_mana, "/", max_mana)

func take_damage(value):
	current_hp -= value
	if main.visualize:
		hp_label.text = str(current_hp, "/", max_hp, " HP")

func is_alive():
	return current_hp > 0

func update_hand_playability():
	for card in hand:
		var cc = card_controls[card.name]
		cc.update_playable(card, self)

class Card:
	var atk := 0
	var def := 0
	var max_def := 0
	var cost := 0
	var has_guard := false
	var has_flying := false
	var has_charge := false
	var can_attack := false
	var name: String
	
	func load_resource(cr: CardResource):
		atk = cr.atk
		def = cr.def
		max_def = cr.def
		cost = cr.cost
		has_guard = cr.has_guard
		has_flying = cr.has_flying
		has_charge = cr.has_charge
		name = cr.get_id()
