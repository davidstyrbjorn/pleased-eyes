package main

import rl "vendor:raylib"

Component_Storage :: struct($T: typeid) {
	sparse:   [dynamic]int, // entity id -> dense index, -1 if missing
	entities: [dynamic]Entity_ID, // dense index -> entity id
	data:     [dynamic]T, // dense index -> component data
}

INVALID_COMPONENT_INDEX :: -1

component_storage_ensure_sparse :: proc(storage: ^Component_Storage($T), entity: Entity_ID) {
	id := int(entity)

	for len(storage.sparse) <= id {
		append(&storage.sparse, INVALID_COMPONENT_INDEX)
	}
}

component_storage_has :: proc(storage: ^Component_Storage($T), entity: Entity_ID) -> bool {
	id := int(entity)

	if id < 0 || id >= len(storage.sparse) {
		return false
	}

	index := storage.sparse[id]
	return index != INVALID_COMPONENT_INDEX
}

component_storage_get :: proc(storage: ^Component_Storage($T), entity: Entity_ID) -> ^T {
	if !component_storage_has(storage, entity) {
		return nil
	}

	return &storage.data[storage.sparse[int(entity)]]
}

component_storage_add :: proc(
	storage: ^Component_Storage($T),
	entity: Entity_ID,
	component: T,
) -> ^T {
	component_storage_ensure_sparse(storage, entity)

	id := int(entity)
	index := storage.sparse[id]

	if index != INVALID_COMPONENT_INDEX {
		storage.data[index] = component
		return &storage.data[index]
	}

	index = len(storage.data)
	storage.sparse[id] = index
	append(&storage.entities, entity)
	append(&storage.data, component)

	return &storage.data[index]
}

component_storage_remove :: proc(storage: ^Component_Storage($T), entity: Entity_ID) {
	if !component_storage_has(storage, entity) {
		return
	}

	// Move the entity we want to remove to the last index, swap with whatever is currently last, then pop

	id := int(entity)
	index := storage.sparse[id]
	last_index := len(storage.data) - 1
	last_entity := storage.entities[last_index]

	storage.data[index] = storage.data[last_index]
	storage.entities[index] = last_entity
	storage.sparse[int(last_entity)] = index

	pop(&storage.data)
	pop(&storage.entities)

	storage.sparse[id] = INVALID_COMPONENT_INDEX
}

component_storage_destroy :: proc(storage: ^Component_Storage($T)) {
	delete(storage.sparse)
	delete(storage.entities)
	delete(storage.data)
}

Entity_ID :: distinct int

/* COMPONENTS */
World_Message :: union {}

World :: struct {
	entities:        [dynamic]Entity_ID,
	free_entities:   [dynamic]Entity_ID,
	next_entity_id:  Entity_ID,
	transforms:      Component_Storage(Transform),
	growing_circles: Component_Storage(Growing_Circle),
	bullets:         Component_Storage(Bullet),
	rectangles:      Component_Storage(Rectangle),
	enemies:         Component_Storage(Enemy),
	nav_cells:       Component_Storage(NavCell),
	messages:        [dynamic]World_Message,
}

entity_world_init :: proc(world: ^World) {
	ESTIMATED_ENTITIES_SPAWN_AT_START :: 256
	world.entities = make([dynamic]Entity_ID, 0, ESTIMATED_ENTITIES_SPAWN_AT_START)
	world.free_entities = make([dynamic]Entity_ID, 0, ESTIMATED_ENTITIES_SPAWN_AT_START)
}

entity_world_destroy :: proc(world: ^World) {
	delete(world.entities)
	delete(world.free_entities)

	component_storage_destroy(&world.transforms)
	component_storage_destroy(&world.growing_circles)
	component_storage_destroy(&world.bullets)
	component_storage_destroy(&world.rectangles)
	component_storage_destroy(&world.enemies)

	world^ = World{}
}

entity_create :: proc(world: ^World) -> Entity_ID {
	// mutates 'entities' & 'free_entities' & 'next_entity_id'
	entity: Entity_ID
	if len(world.free_entities) > 0 {
		last := len(world.free_entities) - 1
		entity = world.free_entities[last]
		pop(&world.free_entities)
	} else {
		entity = world.next_entity_id
		world.next_entity_id += 1
	}

	append(&world.entities, entity)
	return entity
}

entity_destroy :: proc(world: ^World, entity: Entity_ID) {
	if !entity_alive(world, entity) {
		return
	}

	component_storage_remove(&world.transforms, entity)
	component_storage_remove(&world.growing_circles, entity)
	component_storage_remove(&world.bullets, entity)
	component_storage_remove(&world.rectangles, entity)
	component_storage_remove(&world.enemies, entity)

	entity_remove_active(world, entity)
	append(&world.free_entities, entity)
}

entity_remove_active :: proc(world: ^World, entity: Entity_ID) {
	// take the last entity, swap it with the entity we want to remove, then pop
	for i := 0; i < len(world.entities); i += 1 {
		if world.entities[i] == entity {
			last := len(world.entities) - 1
			world.entities[i] = world.entities[last]
			pop(&world.entities)
			return
		}
	}
}

entity_alive :: proc(world: ^World, entity: Entity_ID) -> bool {
	for e in world.entities {
		if e == entity {
			return true
		}
	}
	return false
}

entity_world_send_message :: proc(world: ^World, message: World_Message) {
	append(&world.messages, message)
}

entity_world_clear_message :: proc(world: ^World) {
	clear_dynamic_array(&world.messages)
}
