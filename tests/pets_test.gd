extends TestCase

const FIND := preload("res://trials/find/find.tres")


func _pets() -> Node:
	return App.module(&"Pets")


func _own(id: StringName) -> Pet:
	App.module(&"Inventory").add(id)
	return _pets().pets().filter(func(pet: Pet) -> bool: return pet.id == id)[0]


func _room() -> void:
	App.module(&"Home").open()
	App.module(&"Home")._show(&"room")
	await frames(2)


## Moves the right fingertip into the pet's body and out again.
func _pet(pet: Pet) -> void:
	var body := pet.global_position + Vector3.UP * Pet.BODY
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, body + Vector3.BACK * 0.05))
	await frames(2)
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, body + Vector3(0.2, 0.5, 0.4)))
	await frames(2)


func test_shop_sells_four_pets_once_each_with_spoken_prices() -> void:
	await boot()
	var prices := {}
	for item in ItemDef.all(ItemDef.Kind.PET):
		prices[item.id] = item.price
		expect(not BakedSpeech.paths_for("%s. %d magic stones." % [item.title, item.price]).is_empty(), "spoken price: " + item.title)
	expect_eq(prices, {&"pet_cat": 8, &"pet_dog": 8, &"pet_monkey": 12, &"pet_panda": 12}, "pets and prices")
	var inventory := App.module(&"Inventory")
	inventory.add(&"magic_stone", 20)
	await _room()
	var home := App.module(&"Home")
	home._show(&"pets")
	expect_eq(home._item().id, &"pet_cat", "pets page lists pets")
	expect(inventory.buy(&"pet_cat") and not inventory.buy(&"pet_cat"), "a pet is bought once")
	expect_eq(inventory.count(&"magic_stone"), 12, "charged once")
	await frames(2)
	expect_eq(_pets().pets().size(), 1, "the pet moves in")
	expect(home.find_child("home_buy", true, false) == null, "an owned pet cannot be bought again")
	home.close()


func test_stones_come_from_training_time_only_and_one_at_a_time() -> void:
	var plan := plan_of(FIND, 1)
	await boot(plan)
	var pet := _own(&"pet_cat")
	expect_eq(pet.minutes(), 10, "ten minutes at first")
	pet.progress = pet.minutes() * 60.0 - 0.3
	await wait(0.6)
	expect(not pet.has_stone, "no stone without training")
	App.session.play(plan)
	App.module(&"Home").open()
	await wait(0.6)
	expect(not pet.has_stone, "no stone while the menu pauses training")
	App.module(&"Home").close()
	expect(await until(func() -> bool: return pet.has_stone), "training time earns the stone")
	await wait(0.5)
	expect_eq(pet.progress, 0.0, "nothing more is earned until the stone is taken")


func test_pet_carries_its_stone_to_the_stool_and_the_child_takes_it() -> void:
	await boot()
	var pet := _own(&"pet_dog")
	pet.has_stone = true
	await _room()
	expect(pet.stone.visible and pet.is_visible_in_tree(), "the stone shows in its mouth")
	expect(await until(func() -> bool: return pet.perched and pet.position.is_equal_approx(_pets().stool_top()), 30.0), "it hops onto the stool beside the child")
	expect((pet.global_position + Vector3.UP * Pet.BODY).distance_to(App.head().global_position) < 0.75, "within a seated child's reach")
	await select(pet.stone.global_position)
	expect(not pet.has_stone, "taken")
	expect_eq(App.module(&"Inventory").count(&"magic_stone"), 1, "one stone gained")
	await select(pet.stone.global_position)
	expect_eq(App.module(&"Inventory").count(&"magic_stone"), 1, "an empty mouth gives nothing")
	App.module(&"Home").close()
	expect(not pet.is_visible_in_tree() and pet.stone.collision_layer == 0, "pets stay in the room")


func test_petting_levels_up_after_one_then_three_pets_a_minute_apart() -> void:
	await boot()
	var pet := _own(&"pet_cat")
	await _room()
	await _pet(pet)
	expect_eq([pet.level, pet.minutes()], [1, 9], "the first pet: nine minutes")
	await _pet(pet)
	expect_eq(pet.pets, 0, "a pet within a minute does not count")
	for i in 3:
		expect_eq(pet.level, 1, "three more are needed")
		pet._since_pet = Pet.PET_GAP
		await _pet(pet)
	expect_eq([pet.level, pet.minutes()], [2, 8], "then eight minutes")
	Save.write()
	pet.level = 0
	Save.reload()
	expect_eq(_pets().pets()[0].level, 2, "the level is saved")
	App.module(&"Home").close()


func test_a_palm_held_up_calls_the_pet_over() -> void:
	await boot()
	var pet := _own(&"pet_cat")
	await _room()
	var palm_up := Basis(Vector3.FORWARD, PI)
	var at := App.head().global_position + Vector3(0.1, -0.3, -0.35)
	input.set_hand(&"left", Transform3D(palm_up, at))
	await wait(0.2)
	expect(pet.act != Pet.Act.COME, "a brief turn of the hand calls nothing")
	await wait(0.5)
	expect_eq(pet.act, Pet.Act.COME, "it comes")
	expect(await until(func() -> bool: return pet.perched, 30.0), "onto the stool")
	App.module(&"Home").close()


func test_pet_rests_on_a_cushion_and_gets_up_when_it_is_put_away() -> void:
	await boot()
	App.module(&"Inventory").add(&"cushion")
	var pet := _own(&"pet_panda")
	var other := _own(&"pet_monkey")
	await _room()
	Events.furniture_requested.emit(&"cushion")
	var cushion: Vector3 = _pets().cushions()[0]
	expect_eq(_pets().free_cushion(pet), cushion, "a free cushion")
	pet._mood = Pet.Act.REST
	pet._spot = cushion
	pet._mood_for = 60.0
	expect(_pets().free_cushion(other) == null, "one pet per cushion")
	expect(await until(func() -> bool: return pet._model.position.y < 0.0, 30.0), "it lies down on the cushion")
	expect(pet.position.distance_to(cushion) < 0.1, "on the cushion")
	var decor := App.module(&"Decor")
	Events.selected.emit(&"right", decor.items()[0], Vector3.ZERO, Vector3.FORWARD)
	Events.furniture_store_requested.emit()
	await frames(3)
	expect(pet._mood != Pet.Act.REST or pet._spot != cushion, "no cushion, no rest")
	expect_eq(pet._model.position.y, 0.0, "it stands up")
	App.module(&"Home").close()
