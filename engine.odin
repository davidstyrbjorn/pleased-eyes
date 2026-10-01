package main

import "core:math"
import "core:math/linalg"
// Generic code for particular systems that helps building the
// This leans on raylib, box2d and library_world.odin

import "core:c"
import "core:fmt"
import "core:strings"
import b2d "vendor:box2d"
import rl "vendor:raylib"

Color :: [3]u8

rlxy :: proc(x: f32, y: f32) -> rl.Vector2 {
	return rl.Vector2{x, y}
}

window_size :: proc() -> rl.Vector2 {
	return rl.Vector2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
}

/* Shader stuff */

ShaderUniformValue :: union {
	int,
	f32,
	rl.Vector2,
	rl.Vector3,
	rl.Vector4,
	Color,
}

ShaderUniform :: struct {
	name:     string,
	location: c.int,
	value:    ShaderUniformValue,
}

Shader :: struct {
	rl_shader: rl.Shader,
	uniforms:  [dynamic]ShaderUniform,
}

get_uniform :: proc(shader: ^Shader, name: string) -> ^ShaderUniform {
	for &uniform in shader.uniforms {
		if uniform.name == name {
			return &uniform
		}
	}
	return nil
}

get_uniform_data_type :: proc(uniform: ^ShaderUniform) -> rl.ShaderUniformDataType {
	switch _ in uniform.value {
	case f32:
		return rl.ShaderUniformDataType.FLOAT
	case rl.Vector2:
		return rl.ShaderUniformDataType.VEC2
	case Color:
		return rl.ShaderUniformDataType.VEC3
	case rl.Vector3:
		return rl.ShaderUniformDataType.VEC3
	case rl.Vector4:
		return rl.ShaderUniformDataType.VEC4
	case int:
		return rl.ShaderUniformDataType.INT
	}

	fmt.printf("Invalid uniform type found: %v\n", typeid_of(type_of(uniform.value)))
	return rl.ShaderUniformDataType.INT
}

update_uniform_value :: proc(shader: ^Shader, name: string, value: ShaderUniformValue) {
	uniform := get_uniform(shader, name)
	if uniform != nil {
		uniform.value = value
		rl.SetShaderValue(
			shader.rl_shader,
			uniform.location,
			&uniform.value,
			get_uniform_data_type(uniform),
		)
	} else {
		fmt.printf("Warning: uniform name not found! \"%s\"\n", name)
	}
}

load_shader :: proc(path: string, locations: []ShaderUniform) -> Shader {
	shader: Shader
	shader.rl_shader = rl.LoadShader(nil, strings.clone_to_cstring(path, context.temp_allocator))

	for location in locations {
		append(
			&shader.uniforms,
			ShaderUniform {
				location.name,
				rl.GetShaderLocation(
					shader.rl_shader,
					strings.clone_to_cstring(location.name, context.temp_allocator),
				),
				location.value,
			},
		)
	}

	return shader
}

free_shader :: proc(shader: ^Shader) {
	rl.UnloadShader(shader.rl_shader)
	delete(shader.uniforms)
}

shader_uniform :: proc(name: string, value: ShaderUniformValue) -> ShaderUniform {
	return ShaderUniform{name, 0, value}
}

/* End of shader stuff */

/* Start of UI stuff */

do_button :: proc(text: string, position: rl.Vector2, font_size: f32, font: rl.Font) -> bool {
	mouse_pos := rl.GetMousePosition()
	button_clicked := false

	c_string := strings.clone_to_cstring(text, context.temp_allocator)
	SPACING :: 4.0
	PADDING :: 50
	text_size := rl.MeasureTextEx(font, c_string, font_size, SPACING)
	rect := rl.Rectangle{position.x, position.y, text_size.x + PADDING, text_size.y + PADDING}

	is_hovered := rl.CheckCollisionPointRec(mouse_pos, rect)
	alpha: u8 = 170
	if is_hovered {
		alpha = 255
	}

	rl.DrawRectangleRec(rect, rl.Color{10, 30, 50, alpha})
	rl.DrawTextPro(
		font,
		c_string,
		rlxy(rect.x + PADDING / 2, rect.y + PADDING / 2),
		rlxy(0, 0),
		0.0,
		font_size,
		SPACING,
		rl.WHITE,
	)

	return is_hovered && rl.IsMouseButtonPressed(rl.MouseButton.LEFT)
}

do_button_center :: proc(text: string, offset_y: f32, font_size: f32, font: rl.Font) -> bool {
	mouse_pos := rl.GetMousePosition()
	button_clicked := false

	c_string := strings.clone_to_cstring(text, context.temp_allocator)
	SPACING :: 4.0
	PADDING :: 50
	text_size := rl.MeasureTextEx(font, c_string, font_size, SPACING)
	width := text_size.x + PADDING

	x := (window_size().x / 2) - width / 2

	return do_button(text, rlxy(x, offset_y), font_size, font)
}

do_text :: proc(
	text: string,
	position: rl.Vector2,
	font_size: f32,
	color: rl.Color,
	font: rl.Font,
) {
	c_string := strings.clone_to_cstring(text, context.temp_allocator)
	SPACING :: 4.0
	rl.DrawTextPro(font, c_string, position, rlxy(0.0, 0.0), 0.0, font_size, SPACING, color)
}

do_text_center :: proc(
	text: string,
	offset_y: f32,
	font_size: f32,
	color: rl.Color,
	font: rl.Font,
) {
	ws := window_size()
	c_string := strings.clone_to_cstring(text, context.temp_allocator)
	SPACING :: 4.0
	text_size := rl.MeasureTextEx(font, c_string, font_size, SPACING)
	x := (ws.x / 2.0) - (text_size.x / 2)
	do_text(text, rlxy(x, offset_y), font_size, color, font)
}

/* End of UI stuff */

/* Start of Collision utility using box2d */

// Assume rect's that are sized and positioned according to given Transform's
check_rect_collision :: proc(transform1, transform2: ^Transform) -> bool {
	rect := b2d.MakeBox(transform1.size.x / 2.0, transform1.size.y / 2.0)
	rect2 := b2d.MakeBox(transform2.size.x / 2.0, transform2.size.y / 2.0)

	rectTransform := b2d.Transform {
		p = transform1.position + transform1.size / 2.0,
		q = b2d.Rot_identity,
	}

	rect2Transform := b2d.Transform {
		p = transform2.position + transform2.size / 2.0,
		q = b2d.Rot_identity,
	}

	input: b2d.DistanceInput
	input.proxyA = b2d.MakeProxy(rect.vertices[:], rect.radius)
	input.proxyB = b2d.MakeProxy(rect2.vertices[:], rect2.radius)
	input.transformA = rectTransform
	input.transformB = rect2Transform

	cache: b2d.SimplexCache = {}
	output := b2d.ShapeDistance(input, &cache, nil)

	return output.distance <= 0.0
}

/* End of Collision */

ElapsedTimer :: struct {
	s:          f32,
	interval_s: f32,
	playing:    bool,
}

elapsed_timer_start :: proc(timer: ^ElapsedTimer, interval_s: f32) {
	timer.s = 0
	timer.interval_s = interval_s
}

elapsed_timer_frame_tick :: proc(timer: ^ElapsedTimer, dt: f32) {
	timer.s += dt
}

elapsed_timer_triggered :: proc(timer: ^ElapsedTimer) -> bool {
	if !timer.playing {
		return false
	}

	if timer.s >= timer.interval_s {
		timer.s = 0
		return true
	}
	return false
}

elapsed_timer_reset :: proc(timer: ^ElapsedTimer) {
	timer.s = 0
	timer.playing = true
}

Vector2i :: [2]int

import "base:intrinsics"

Timeline_Easing :: enum {
	LINEAR,
	CUBIC,
}

Timeline :: struct {
	v:        ^f32,
	from:     f32,
	to:       f32,
	duration: f32,
	easing:   Timeline_Easing,
}

Timelines :: struct {
	current: int,
	t:       f32,
	list:    [dynamic]Timeline,
}

timelines_add :: proc(timelines: ^Timelines, timeline: Timeline) {
	append(&timelines.list, timeline)
}

timelines_set_frame :: proc(timelines: ^Timelines, frame: int) {
	assert(frame >= 0 && frame < len(timelines.list))
	timelines.current = frame
	timelines.list[frame].v^ = timelines.list[frame].from
	timelines.t = 0.0
}

timelines_destroy :: proc(timelines: ^Timelines) {
	delete(timelines.list)
}

timelines_play :: proc(timelines: ^Timelines, dt: f32) {
	// Check if we have any at all or maybe we're at the end
	if len(timelines.list) == 0 || timelines.current >= len(timelines.list) {
		return
	}

	timeline := &timelines.list[timelines.current]
	timelines.t = min(timelines.t + dt / timeline.duration, 1.0)
	timeline.v^ = linalg.lerp(timeline.from, timeline.to, timelines.t)

	// Advance to next timeline	
	if abs(timelines.t - 1.0) < math.F32_EPSILON {
		timelines.current += 1
		timelines.t = 0
	}
}

Music_Player_Entry :: struct {
	music:  rl.Music,
	volume: f32,
}

Music_Player :: struct {
	master_volume:     f32,
	songs:             [dynamic]Music_Player_Entry,
	currently_playing: int,
}

music_player_add :: proc(mp: ^Music_Player, path: cstring) -> int {
	music := rl.LoadMusicStream(path)
	append(&mp.songs, Music_Player_Entry{music = music, volume = 0.0})
	return len(mp.songs) - 1
}

// Note: call this after adding all your songs!
music_player_init :: proc(mp: ^Music_Player, master_volume: f32) {
	for e in mp.songs {
		rl.PlayMusicStream(e.music)
	}
	mp.master_volume = master_volume
}

music_player_set_current :: proc(mp: ^Music_Player, current: int) {
	mp.currently_playing = current
}

music_player_destroy :: proc(mp: ^Music_Player) {
	for e in mp.songs {
		rl.UnloadMusicStream(e.music)
	}
	delete(mp.songs)
}

music_player_update :: proc(mp: ^Music_Player, dt: f32) {
	for &e, i in mp.songs {
		if i != mp.currently_playing {
			e.volume = math.lerp(e.volume, 0.0, dt * 2)
		} else {
			e.volume = math.lerp(e.volume, mp.master_volume, dt * 2)
		}
		rl.SetMusicVolume(e.music, e.volume)
		rl.UpdateMusicStream(e.music)
	}
}
