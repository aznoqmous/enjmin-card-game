@tool
extends Node
class_name Main

@export var player_1: Player
@export var player_2: Player

var player_1_starting_deck: Array[CardResource]
var player_2_starting_deck: Array[CardResource]

var cards: Array[CardResource]
var deck_size := 30

@export_tool_button("GENERATE CARDS") var generate = generate_cards
@export_tool_button("CREATE DECKS") var create = create_decks

@export_category("SIMULATION")
@export var iterations := 100
@export var cycles := 100
@export_group("REINFORCED")
@export var reinforced_training := false
@export var reinforced_training_threshold := 0.9
@export_group("EFFICIENCY")
@export var has_efficiency := false
@export var do_clear_cards_efficiency := false

#@export_tool_button("PLAY GAME") var play = play_game
@export_tool_button("PLAY GAMES") var plays = simulation
@export_tool_button("COPY PLAYER 1 DECK TO PLAYER 2") var copy_deck = copy_player_deck
@export_tool_button("PLAYER 1 CREATE OPTIMIZED DECK") var create_optimized = create_optimized_deck

@export_category("SAVE/LOAD")
@export_tool_button("SAVE DECK") var save = save_deck
@export_tool_button("LOAD PLAYER 1 DECK") var load_1 = load_player_1_deck
@export_tool_button("LOAD PLAYER 2 DECK") var load_2 = load_player_2_deck
@export_tool_button("LOAD STARTING DECKS") var load_starting = load_starting_decks
@export_tool_button("PRINT PLAYER 1 DECK") var print_player_1 = print_player_1_deck
@export_tool_button("PRINT PLAYER 2 DECK") var print_player_2 = print_player_2_deck
@export_multiline var load_string : String

@export_category("VISUALIZER")
@export var visualize := true
@export var visualizer_speed := 0.5

var cards_efficiency = {}

func _ready():
	generate_cards()
	create_decks()

var skills = [
	[], [1], [2], [3], [1, 2], [1, 3], [2, 3], [1, 2, 3]
];

var max_cost := 7
func generate_cards():
	cards.clear()
	var trisks = []
	for atk in range(0, max_cost * 2.0 + 2.0):
		for def in range(1, max_cost * 2.0 + 2.0):
			for sks in skills:
				var card = CardResource.new()
				card.atk = atk
				card.def = def
				card.has_guard = sks.has(1)
				card.has_flying = sks.has(2)
				card.has_charge = sks.has(3)
				if card.cost > max_cost: continue
				card.resource_name = card.get_id()
				cards.append(card)
				print(card)
				
	clear_cards_efficiency()
	
	print("Card pool : ", cards.size())
	

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
	
	player_1_starting_deck = player_1.cards.duplicate()
	player_2_starting_deck = player_2.cards.duplicate()

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
		await play_turn(opponent)
		
	return current_turn

func card_attack_animation(cc: CardControl, pos):
	var previous_position = cc.global_position
	cc.z_index = 10
	get_tree().create_tween().tween_property(cc, "global_position", pos, 0.3 * visualizer_speed)
	await get_tree().create_timer(0.3 * visualizer_speed).timeout
	get_tree().create_tween().tween_property(cc, "global_position", previous_position, 0.5 * visualizer_speed)
	await get_tree().create_timer(0.5 * visualizer_speed).timeout
	cc.z_index = 0

var turn_index := 0
func play_turn(player: Player):
	turn_index += 1
	current_turn = player
	opponent = player_1 if player == player_2 else player_2

	await player.start_turn()
	if visualize: player.update_hand_playability()
			
	while player.play_costest_card():
		await wait()
		if visualize: player.update_hand_playability()
			
	for card in player.terrain:
		if card.can_attack or card.has_charge:
			var guarded = false
			for ocard in opponent.terrain:
				if ocard.has_guard and ocard.def > 0:
					if card.has_flying and not ocard.has_flying: continue
					resolve_card_combat(card, ocard)
					if visualize:
						await card_attack_animation(player.card_controls[card.name], opponent.card_controls[ocard.name].global_position)
						opponent.card_controls[ocard.name].load_card(ocard)
						player.card_controls[card.name].load_card(card)
						player.card_controls[card.name].def_label.modulate = Color.RED
						opponent.card_controls[ocard.name].def_label.modulate = Color.RED
					guarded = true
					break
					
			if guarded: continue
			
			if visualize:
				var cc = player.card_controls[card.name]
				await card_attack_animation(cc, opponent.portrait.global_position)
			opponent.take_damage(card.atk)
			
	for card in player.terrain:
		if card.def <= 0:
			player.discard_pile.append(card)
			player.terrain.erase(card)
			if visualize:
				player.card_controls[card.name].queue_free()
		card.def = card.max_def
		if visualize:
			player.card_controls[card.name].def_label.text = str(card.def)
			player.card_controls[card.name].def_label.modulate = Color.WHITE

	for card in opponent.terrain:
		if card.def <= 0:
			opponent.discard_pile.append(card)
			opponent.terrain.erase(card)
			if visualize:
				opponent.card_controls[card.name].queue_free()
		card.def = card.max_def
		if visualize:
			opponent.card_controls[card.name].def_label.text = str(card.def)
			opponent.card_controls[card.name].def_label.modulate = Color.WHITE
	
	await player.end_turn()

func resolve_card_combat(attacker: Player.Card, defender: Player.Card):
	defender.def -= attacker.atk 
	attacker.def -= defender.atk

func simulation():
	var start = Time.get_ticks_msec()
	var last_deck = player_1.cards.duplicate()
	var best_win_ratio = 0.0
	var last_win_ratio = 0.0
	#player_2.cards = create_deck()
	player_1.update_deck_cards()
	player_2.update_deck_cards()
	
	var stats = []
	
	if visualize:
		await play_games(1)
		return;
	
	pressClearButton()
	print("STARTING DECK")
	player_1.show_deck()
	player_1.show_card_costs()
	
	var added_card : CardResource
	var removed_card : CardResource
	
	if do_clear_cards_efficiency:
		clear_cards_efficiency()
		
	var max_average_turn_for_win = 100000
	var max_quickest_win = 100000
	
	var changes := 0
	for i in iterations:
		var win_ratio = await play_games(cycles) / average_turn_for_win
		await get_tree().create_timer(0).timeout
		if max_average_turn_for_win > average_turn_for_win: max_average_turn_for_win = average_turn_for_win
		if max_quickest_win > quickest_win: max_quickest_win = quickest_win
		
		#print(floor(i / float(iterations) * 100.0), "%")
		#player_1.show_card_costs()
		#print("Current win/best : ", win_ratio, "/", best_win_ratio)

		if win_ratio < best_win_ratio:
			# regression
			player_1.cards = last_deck.duplicate()
			if added_card and has_efficiency:
				cards_efficiency[added_card.get_id()].value -= best_win_ratio - win_ratio
				cards_efficiency[removed_card.get_id()].value += best_win_ratio - win_ratio

		else:
			# progression
			stats.append({
				"step": i,
				"win_ratio": win_ratio,
				"average_turn_for_win": average_turn_for_win,
				"card_costs": player_1.get_card_costs()
			})
			if best_win_ratio: changes += 1
			last_deck = player_1.cards.duplicate()
			best_win_ratio = win_ratio
			print("Best win ratio : ", best_win_ratio, " - ", i)
			if added_card:
				cards_efficiency[added_card.get_id()].value += best_win_ratio - win_ratio
				cards_efficiency[removed_card.get_id()].value -= best_win_ratio - win_ratio
		
		if reinforced_training and win_ratio >= reinforced_training_threshold:
			best_win_ratio = 0.0
			player_2.cards = player_1.cards.duplicate()
			player_2.update_deck_cards()
			if do_clear_cards_efficiency:
				clear_cards_efficiency()
		else:
			if has_efficiency:
				removed_card = remove_worst_card(player_1)
				player_1.cards.erase(removed_card)
				added_card = add_random_best_card(player_1)
				player_1.cards.append(added_card)
				player_1.update_deck_cards()
			else:
				removed_card = player_1.cards.pick_random()
				player_1.cards.erase(removed_card)
				added_card = add_random_card(player_1)
				player_1.cards.append(added_card)
				player_1.update_deck_cards()
		
		if not i % 10:
			var pstr = "["
			for p in 100.0:
				pstr = str(pstr, "#" if p / 100.0 < i / float(iterations) else " ")
			pstr = str(pstr, "] - ", win_ratio, " - ", best_win_ratio, " - ", max_average_turn_for_win, " - ", max_quickest_win)
			print(pstr)
		if win_ratio == 1: break;
		
		last_win_ratio = win_ratio

	pressClearButton()
	
	print("-----------------------------")
	print("Iterations : ", iterations)
	print("Cycles : ", cycles)
	print("Time spent :", floor((Time.get_ticks_msec() - start) / 100.0) / 10.0, "s")
	print("Number of changes : ", changes)
	print("-----------------------------")
	player_1.cards = last_deck.duplicate()
	print("Best deck so far : ", best_win_ratio * 100.0, "% winrate")
	player_1.show_deck()
	player_1.show_card_costs()
	print("Average turn for win ", max_average_turn_for_win)
	print("Quickest win ", max_quickest_win)
	
	print("| STEP      | WR         | NBT      | COSTS")
	for s in stats:
		var card_costs = ""
		for cost in s.card_costs.values():
			card_costs = str(card_costs, " ", cost)
		print("|      %4d |       %1.2f |   %2.4f | %s" % [s.step, s.win_ratio, s.average_turn_for_win, card_costs])
		#print(s.step, " - WR ", s.win_ratio, " - avg nbt", s.average_turn_for_win)
	
	#print("Cards efficiency:")
	#var ce_total = 0
	#var ce = cards_efficiency.values()
	#ce.sort_custom(func(a, b): return a.value > b.value)
	#for c in ce:
		#if c.value == 0.0: continue
		#ce_total += 1
		#print(c.card.get_id(), " ", c.value)
	#print(ce_total, "/", cards.size(), " cards tested")
	
	#print("Opponent deck : ")
	#player_2.show_deck()
	#player_2.show_card_costs()

func clear_cards_efficiency():
	cards_efficiency.clear()
	for card in cards:
		cards_efficiency[card.get_id()] = {"card": card, "value": 0}

func add_random_best_card(player: Player) -> CardResource:
	var player_res = player.cards.map(func(c: CardResource): return c.get_id())
	var ce = cards_efficiency.values().filter(func(c): return not player_res.has(c.card.get_id()))
	ce.shuffle()
	
	# force unrated card
	for c in ce:
		if c.value == 0.0: return c.card
		
	ce.sort_custom(func(a, b): return a.value > b.value)
	return ce[0].card
	
func remove_worst_card(player: Player) -> CardResource:
	#return player.cards.pick_random()
	var player_res = player.cards.map(func(c: CardResource): return c.get_id())
	var ce = cards_efficiency.values().filter(func(c): return player_res.has(c.card.get_id()))
	
	# force unrated card
	for c in ce:
		if c.value == 0.0: return c.card
		
	ce.sort_custom(func(a, b): return a.value < b.value)
	return ce[0].card
	
func add_random_card(player: Player):
	var player_res = player.cards.map(func(c: CardResource): return c.get_id())
	var available_cards = cards.filter(func(c: CardResource): return not player_res.has(c.get_id()))
	return available_cards.pick_random()

var quickest_win := 100
var average_turn_for_win := 0.0
func play_games(total_games: int) -> float:
	var start = Time.get_ticks_msec()
	var player_1_win := 0
	var turn_win := 0
	quickest_win = 100
	for i in total_games:
		var winner = await play_game(player_1 if i < float(total_games) / 2.0 else player_2)
		if winner == player_1:
			player_1_win += 1
			turn_win += turn_index
			if turn_index < quickest_win: quickest_win = turn_index
	average_turn_for_win = float(turn_win) / float(player_1_win)
	#print("Avg turns for win : ", float(turn_win) / float(player_1_win), " - ", turn_win, "/", player_1_win)
	#print("Quickest win : ", quickest_win, " turns")
	#print("Total time : ", Time.get_ticks_msec() - start, "ms")
	#if player_1_win <= 0: return 0.0
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

func print_decks(player):
	print("Player 1")
	player_1.save_deck()
	
	print("Player 2")
	player_2.save_deck()
	
		
func load_player_1_deck():
	player_1.cards = load_deck(load_string)
	print("Loaded player_1 deck !")
	player_1.show_deck()
	player_1.show_card_costs()
	
func load_player_2_deck():
	player_2.cards = load_deck(load_string)
	print("Loaded player_2 deck !")
	player_2.show_deck()
	player_2.show_card_costs()

func load_starting_decks():
	player_1.cards = player_1_starting_deck.duplicate()
	player_2.cards = player_2_starting_deck.duplicate()

func load_deck(deck_string) -> Array[CardResource]:
	var res_cards : Array[CardResource]
	for line in deck_string.split("\n"):
		var card_spec = line.split("_")
		var cr = CardResource.new()
		if card_spec.size() < 3: continue;
		#cr.cost = int(card_spec[0])
		cr.atk = int(card_spec[1])
		cr.def = int(card_spec[2])
		cr.has_guard = card_spec[3] == "1"
		cr.has_flying = card_spec[4] == "1"
		cr.has_charge = card_spec[5] == "1"
		if cr.cost > 7:
			print("UNVALID DECK - UNVALID CARD COST : ", cr.cost)
			return res_cards
		res_cards.append(cr)
	
	if res_cards.size() != deck_size:
		print("UNVALID DECK - DECK DOESNT CONTAINS ", deck_size, " CARDS (", res_cards.size(), ")")
		return res_cards
	
	var cardz = {}
	for card in res_cards:
		cardz[card] = 1
	if cardz.size() != res_cards.size():
		print("UNVALID DECK - CARDS ARE NOT UNIQUE")
		return res_cards
	
	print("--- VALID DECK LOADED ---")
	return res_cards

func wait(v:=1.0):
	if not visualize: return;
	await get_tree().create_timer(visualizer_speed * v).timeout

func create_optimized_deck():
	player_1.cards.clear()
	var ce = cards_efficiency.values()
	ce.sort_custom(func(a, b): return a.value > b.value)
	for i in deck_size:
		player_1.cards.append(ce[i].card)
	player_1.update_deck_cards()

func print_player_1_deck():
	print("--- PLAYER 1 ---")
	print(player_1.save_deck())
	
func print_player_2_deck():
	print("--- PLAYER 2 ---")
	print(player_2.save_deck())
