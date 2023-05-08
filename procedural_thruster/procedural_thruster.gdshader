// MIT License
// Copyright (c) 2023, Thomas Piquet

shader_type canvas_item;

uniform sampler2D input_texture : filter_nearest;

void fragment() {
    vec2 uv = UV;
    vec4 color = texture(input_texture, uv);
    COLOR = color;
}