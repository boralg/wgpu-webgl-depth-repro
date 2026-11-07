@vertex
fn vs_fullscreen(@builtin(vertex_index) i: u32) -> @builtin(position) vec4<f32> {
    let uv = vec2<f32>(f32((i << 1u) & 2u), f32(i & 2u));
    return vec4<f32>(uv * 2.0 - 1.0, 0.5, 1.0);
}

@group(0) @binding(0) var depth: texture_2d<f32>;
@group(0) @binding(1) var nearest: sampler;

const GREEN: vec4<f32> = vec4<f32>(0.0, 1.0, 0.0, 1.0);
const RED: vec4<f32> = vec4<f32>(1.0, 0.0, 0.0, 1.0);

fn is_correct(read: f32) -> vec4<f32> {
    return select(RED, GREEN, abs(read - 0.5) < 0.01);
}

@fragment
fn fs_load() -> @location(0) vec4<f32> {
    return is_correct(textureLoad(depth, vec2<i32>(0, 0), 0).r);
}

@fragment
fn fs_sample() -> @location(0) vec4<f32> {
    return is_correct(textureSampleLevel(depth, nearest, vec2<f32>(0.5, 0.5), 0.0).r);
}
