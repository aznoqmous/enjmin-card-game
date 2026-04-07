@tool
extends Node
class_name Main

@export var player_1: Player
@export var player_2: Player
var cards: Array[CardResource]
var deck_size := 30

@export_tool_button("GENERATE CARDS") var generate = generate_cards
@export_tool_button("CREATE DECKS") var create = create_decks

@export_category("SIMULATION")
@export var iterations := 100
@export var cycles := 100
#@export_tool_button("PLAY GAME") var play = play_game
@export_tool_button("PLAY GAMES") var plays = simulation

@export_category("SAVE/LOAD")
@export_tool_button("COPY PLAYER 1 DECK TO PLAYER 2") var copy_deck = copy_player_deck
@export_tool_button("SAVE DECK") var save = save_deck
@export_tool_button("LOAD PLAYER 1 DECK") var load_1 = load_player_1_deck
@export_tool_button("LOAD PLAYER 2 DECK") var load_2 = load_player_2_deck
@export_multiline var load_string : String

@export_category("VISUALIZER")
@export var visualize := true
@export var visualizer_speed := 0.5


@export var player_1_hand_control: Control
@export var player_2_hand_control: Control

func _ready():
	generate_cards()
	create_decks()

var max_cost := 7
func generate_cards():
	cards.clear()
	for atk in range(0, 16):
		for def in range(1, 16):
			var card = CardResource.new()
			card.atk = atk
			card.def = def
			if card.cost > max_cost: continue
			card.resource_name = str("CARD_", card.cost, "_", atk, "_", def)
			cards.append(card)
			print(card)
	print(cards.size())

func create_deck() -> Array[CardResource]:
	var deck : Array[CardResource]
	var available_cards := cards.duplicate()
	for i in deck_size:
		var c = available_cards.pick_random()
		available_cards.erase(c)
		deck.append(c)
	return deck

func create_decks():
	player_1.cards = create_deck()
	player_2.cards = create_deck()
	
	player_1.show_deck()
	player_1.show_card_costs()

var current_turn : Player
var opponent : Player
func play_game(first_player: Player) -> Player:
	turn_index = 0
	
	player_1.clear_visuals()
	player_2.clear_visuals()
	
	await player_1.start_game()
	await player_2.start_game()
	
	current_turn = player_1
	opponent = first_player
	while player_1.is_alive() and player_2.is_alive():
		#await get_tree().create_timer(0.1).timeout
		await play_turn(opponent)
		
	#print(current_turn.name, " win !")
	return current_turn

var turn_index := 0
func play_turn(player: Player):
	turn_index += 1
	current_turn = player
	opponent = player_1 if player == player_2 else player_2
	#print(current_turn.name, " - ", current_turn.current_hp)
	#print(player.name, " turn ", turn_index)
	await player.start_turn()
	while player.play_costest_card():
		await wait()
		
	for card in player.terrain:
		if card.can_attack:
			#print(" - ", card.name, " attacks for ", card.atk)
			await wait()
			opponent.take_damage(card.atk)
			#print(" - ", opponent.name, " got ", opponent.current_hp, " hp left")
	player.end_turn()

func simulation():
	var last_deck = player_1.cards.duplicate()
	var last_win_ratio = 0.0
	#player_2.cards = create_deck()

	pressClearButton()
	for i in iterations:
		var win_ratio = await play_games(cycles)
		print(floor(i / float(iterations) * 100.0), "%")
		player_1.cards.erase(player_1.cards.pick_random())
		player_1.cards.append(add_random_card(player_1))

		if win_ratio < last_win_ratio:
			player_1.cards = last_deck.duplicate()
		else:
			last_deck = player_1.cards.duplicate()
			last_win_ratio = win_ratio
		
		player_1.show_card_costs()
		
		print("Current win/best : ", win_ratio, "/", last_win_ratio)
		#var pstr = "["
		#for p in 100.0:
			#pstr = str(pstr, "#" if p / 100.0 < i / iterations else " ")
		#pstr = str(pstr, "]")
		#print(pstr)
		if win_ratio == 1: break;
		
		
	print("Best deck so far : ", last_win_ratio * 100.0, "% winrate")
	player_1.show_deck()
	player_1.show_card_costs()
	print("Opponent deck : ")
	player_2.show_deck()
	player_2.show_card_costs()
		
func add_random_card(player: Player):
	var available_cards = cards.duplicate()
	for card in player.cards:
		available_cards.erase(card)
	return available_cards.pick_random()
	
func play_games(total_games: int) -> float:
	var player_1_win := 0
	var turn_win := 0
	for i in total_games:
		var winner = await play_game(player_1 if i < float(total_games) / 2.0 else player_2)
		if winner == player_1:
			player_1_win += 1
			turn_win += turn_index
		await get_tree().create_timer(0).timeout
		#print("Game n°", i)
	print("Avg turns for win : ", float(turn_win) / float(player_1_win))
	return float(player_1_win) / float(total_games)

func pressClearButton()->void:
	var shortcut:= EditorInterface.get_editor_settings().get_shortcut("editor/clear_output").get_as_text()
	var root:=EditorInterface.get_inspector().get_tree().root
	_pressClearButton(root, shortcut)

func _pressClearButton(node:Node, shortcutText:String)->bool:
	for i in node.get_child_count():
		var child:= node.get_child(i)
		if child is Button:
			var b:= child as Button
			if b.shortcut:
				if b.shortcut.get_as_text() == shortcutText:
					b.pressed.emit()
					return true
		if child.get_child_count() > 0:
			if _pressClearButton(child, shortcutText):
				return true
	return false

func copy_player_deck():
	player_2.cards = player_1.cards.duplicate()

func save_deck():
	var data = player_1.save_deck()
	var save_path = "res://"
	var filename = "save.txt"
	var file : FileAccess
	file = FileAccess.open(save_path + filename, FileAccess.WRITE)
	file.store_line(data)
	file.close()
		
func load_player_1_deck():
	player_1.cards = load_deck(load_string)
	
func load_player_2_deck():
	player_2.cards = load_deck(load_string)

func load_deck(deck_string) -> Array[CardResource]:
	var res_cards : Array[CardResource]
	for line in deck_string.split("\n"):
		var card_spec = line.split("_")
		var cr = CardResource.new()
		if card_spec.size() < 3: continue;
		cr.cost = int(card_spec[0])
		cr.atk = int(card_spec[1])
		cr.def = int(card_spec[2])
		res_cards.append(cr)
	return res_cards

func wait(v:=1.0):
	await get_tree().create_timer(visualizer_speed * v).timeout
