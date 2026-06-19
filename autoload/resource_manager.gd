extends Node

signal fuel_changed(new_value: int, max_value: int)
signal scrap_changed(new_value: int)
signal medicine_changed(new_value: int)
signal bike_durability_changed(new_value: int, max_value: int)
signal fuel_warning(level: StringName)

var fuel: int = 20
var tank_capacity: int = 30
var scrap: int = 0
var medicine: int = 0
var medicine_max: int = 3
var bike_durability: int = 15
var bike_max_durability: int = 15

func reset() -> void:
	fuel = 20
	tank_capacity = 30
	scrap = 0
	medicine = 1
	bike_durability = 15
	bike_max_durability = 15
	_emit_all()

func add_fuel(amount: int) -> void:
	fuel = mini(fuel + amount, tank_capacity)
	fuel_changed.emit(fuel, tank_capacity)
	_check_fuel_warning()

func consume_fuel(amount: int) -> bool:
	if fuel < amount:
		return false
	fuel -= amount
	fuel_changed.emit(fuel, tank_capacity)
	_check_fuel_warning()
	return true

func add_scrap(amount: int) -> void:
	scrap += amount
	scrap_changed.emit(scrap)

func consume_scrap(amount: int) -> bool:
	if scrap < amount:
		return false
	scrap -= amount
	scrap_changed.emit(scrap)
	return true

func add_medicine(amount: int) -> void:
	medicine = mini(medicine + amount, medicine_max)
	medicine_changed.emit(medicine)

func use_medicine() -> bool:
	if medicine <= 0:
		return false
	medicine -= 1
	medicine_changed.emit(medicine)
	return true

func damage_bike(amount: int) -> void:
	bike_durability = maxi(0, bike_durability - amount)
	bike_durability_changed.emit(bike_durability, bike_max_durability)

func repair_bike(amount: int) -> void:
	bike_durability = mini(bike_durability + amount, bike_max_durability)
	bike_durability_changed.emit(bike_durability, bike_max_durability)

func get_fuel_state() -> StringName:
	if fuel >= 6:
		return &"normal"
	elif fuel >= 3:
		return &"warning"
	elif fuel >= 1:
		return &"danger"
	else:
		return &"empty"

func _check_fuel_warning() -> void:
	fuel_warning.emit(get_fuel_state())

func _emit_all() -> void:
	fuel_changed.emit(fuel, tank_capacity)
	scrap_changed.emit(scrap)
	medicine_changed.emit(medicine)
	bike_durability_changed.emit(bike_durability, bike_max_durability)
	_check_fuel_warning()
