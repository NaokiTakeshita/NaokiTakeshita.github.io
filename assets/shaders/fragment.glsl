/*
This code is a modified version of work originally published by Liam Egan:
https://codepen.io/shubniggurath/pen/OEeMOd

Copyright (c) 2025 by Liam Egan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

// shaders/fragment.glsl

uniform vec2 u_resolution;
uniform vec3 u_mouse;
uniform float u_time;
uniform sampler2D u_noise;
uniform sampler2D u_buffer;
uniform sampler2D u_environment;
uniform sampler2D u_texture;
uniform sampler2D u_texture2;
uniform sampler2D u_texture3;
uniform float u_texture_width;
uniform float u_texture_height;
uniform bool u_renderpass;
uniform int u_frame;
uniform float u_stage;
uniform float u_wave_timing;

#define PI 3.141592653589793
#define TAU 6.283185307179586
#define rain 1
#define depth 20.0
#define velPropagation 1.4
#define pow2(x)(x * x)

// Holy fuck balls, fresnel!
const float bias = 0.2;
const float scale = 10.0;
const float power = 10.1;

// blur constants
const float blurMultiplier = 0.95;
const float blurStrength = 2.98;
const int samples = 8;
const float sigma = float(samples) * 0.25;

vec2 hash2(vec2 p)
{
  vec2 o = texture2D(u_noise, (p + 0.5) / 256.0, - 100.0).xy;
  return o;
}

float gaussian(vec2 i) {
  return 1.0 / (2.0 * PI * pow2(sigma)) * exp(-((pow2(i.x) + pow2(i.y)) / (2.0 * pow2(sigma))));
}

vec3 hash33(vec3 p) {
  
  float n = sin(dot(p, vec3(7, 157, 113)));
  return fract(vec3(2097152, 262144, 32768) * n);
}

vec3 blur(sampler2D sp, vec2 uv, vec2 scale) {
  vec3 col = vec3(0.0);
  float accum = 0.0;
  float weight;
  vec2 offset;
  
  for(int x =- samples / 2; x < samples / 2; ++ x) {
    for(int y =- samples / 2; y < samples / 2; ++ y) {
      offset = vec2(x, y);
      weight = gaussian(offset);
      col += texture2D(sp, uv + scale * offset).rgb * weight;
      accum += weight;
    }
  }
  
  return col / accum;
}

vec3 hsb2rgb(in vec3 c) {
  vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
  rgb = rgb * rgb * (3.0 - 2.0 * rgb);
  return c.z * mix(vec3(1.0), rgb, c.y);
}

vec3 domain(vec2 z) {
  return vec3(hsb2rgb(vec3(atan(z.y, z.x) / TAU, 1.0, 1.0)));
}
vec3 colour(vec2 z) {
  return domain(z);
}

const float delta = 0.005;

vec4 renderRipples() {
  vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / min(u_resolution.y, u_resolution.x);
  vec3 e = vec3(vec2(3.6) / u_resolution.xy, 0.0);
  vec2 sample = gl_FragCoord.xy / u_resolution.xy;
  float ratio = u_resolution.x / u_resolution.y;
  vec2 mouse = u_mouse.xy - uv;
  
  vec4 fragcolour = texture2D(u_buffer, sample);
  
  float shade = 0.0;
  
  // float shade = 1. - smoothstep(.1, .15, length(mouse));
  if (u_mouse.z == 1.0) {
    // マウス発火場所に波紋
    shade = smoothstep(0.02 + abs(sin(u_time * 10.0) * 0.006), 0.0, length(mouse));
    
    // 中央から
    // shade = smoothstep(0.02 + abs(sin(u_time * 10.0) * 0.006), 0.0, length(uv));
  }
  
  // --- 最初の方で波紋をつくる
  // float mixRatio = fract(u_stage);
  // if (mixRatio > 0.2 && mixRatio < 0.8) {
    //   float radius = 0.02 + abs(sin(u_time * 10.0) * 0.006);
    //   shade = smoothstep(radius, 0.0, length(uv + vec2(-0.3, 0.0))); // 中央（uv = 0）から波紋
  // }else if (u_stage > 2.0) {
  // }else if (fract(u_stage) == 0.0) {
    //   // shade = 0.0;
  // }
  
  //
  //
  //
  if (u_wave_timing == 1.0) {
    float radius = 0.02 + abs(sin(u_time * 10.0) * 0.006);
    shade = smoothstep(radius, 0.0, length(uv + vec2(sin(u_time * 2.0), cos(u_time)) / 5.0 + vec2(-0.3, 0.0))); // 中央（uv = 0）から波紋
  }else if (u_wave_timing == 2.0) {
    float radius = 0.02 + abs(sin(u_time * 10.0) * 0.006);
    shade = smoothstep(radius, 0.0, length(uv + vec2(sin(u_time * 2.0), cos(u_time)) / 5.0 + vec2(0.3, 0.0))); // 中央（uv = 0）から波紋
  }
  
  //
  //
  //
  //
  //
  
  // if (u_frame < 30 * 3) {
    //   shade = 0.0;
  // }else {
    //   float radius = 0.02 + abs(sin(u_time * 10.0) * 0.006);
    //   shade = smoothstep(radius, 0.0, length(uv + vec2(-0.3, 0.0))); // 中央（uv = 0）から波紋
  // }
  //   else if (u_frame < 150) {
    //   // shade = 0.0;
  // }else if (u_frame < 200) {
    //   float radius = 0.02 + abs(sin(u_time * 10.0) * 0.006);
    //   shade = smoothstep(radius, 0.0, length(uv));
  // }
  // console.log(u_frame);
  
  // if (mod(u_time, 0.1) >= 0.095) {
    //   vec2 hash = hash2(vec2(u_time * 2.0, sin(u_time * 10.0))) * 3.0 - 1.0;
    //   shade += smoothstep(0.012, 0.0, length(uv - hash + 0.5));
  // }
  
  // shade -= (smoothstep(0.185, 0.0, length(mouse)) - shade) * 2.0;
  
  vec4 texcol = fragcolour;
  
  float d = shade * 2.0;
  
  float t = texture2D(u_buffer, sample - e.zy, 1.0).x;
  float r = texture2D(u_buffer, sample - e.xz, 1.0).x;
  float b = texture2D(u_buffer, sample + e.xz, 1.0).x;
  float l = texture2D(u_buffer, sample + e.zy, 1.0).x;
  
  // float t = texture2D(u_buffer, sample + vec2(0., -delta*ratio)).x;
  // float r = texture2D(u_buffer, sample + vec2(delta, 0.)).x;
  // float b = texture2D(u_buffer, sample + vec2(0., delta*ratio)).x;
  // float l = texture2D(u_buffer, sample + vec2(-delta, 0.)).x;
  
  // fragcolour = (fragcolour + t + r + b + l) / 5.;
  d +=- (texcol.y - 0.5) * 2.0 + (t + r+b + l-2.0);
  d *= 0.99;
  d *= float(u_frame > 5);
  d = d*0.5 + 0.5;
  
  fragcolour = vec4(d, texcol.x, 0, 0);
  
  return fragcolour;
}

//   Naive environment mapping. Pass the reflected vector and pull back the texture position for that ray.
vec3 envMap(vec3 rd, vec3 sn, float scale) {
  
  rd.xy -= u_time * 0.2; // This just sort of compensates for the camera movement
  // rd.xy -= movement;
  rd *= 1.0; // scale the whole thing down a but from the scaled UVs
  
  vec3 col = texture2D(u_environment, rd.xy - 0.5).rgb * 2.0;
  col *= normalize(col);
  // col *= vec3(1., 1., 1.2);
  // col *= vec3(hash2(rd.xy).y * .5 + .5);
  
  return col;
  
}

float bumpMap(vec2 uv, float height, inout vec3 colourmap) {
  
  vec3 shade;
  
  vec2 sample = gl_FragCoord.xy / u_resolution.xy;
  sample += uv;
  vec2 ps = vec2(1.0) / u_resolution.xy;
  
  shade = vec3(blur(u_buffer, sample, ps * blurStrength));
  // shade = texture2D(u_buffer, sample).rgb;
  // shade = vec3(shade.y * shade.y);
  
  return 1.0 - shade.x * height;
}
float bumpMap(vec2 uv, float height) {
  vec3 colourmap;
  return bumpMap(uv, height, colourmap);
}

vec4 renderPass(vec2 uv, inout float distortion) {
  vec3 surfacePos = vec3(uv, 0.0);
  vec3 ray = normalize(vec3(uv, 1.0));
  // vec3 lightPos = vec3(cos(u_time / 2.) * 2., sin(u_time / 2.) * 2., -3.);
  vec3 lightPos = vec3(cos(u_time * 0.4 + 3.0) * 2.0, 1.0 + sin(u_time * 0.3 + 2.0) * 2.0, - 3.0);
  vec3 normal = vec3(0.0, 0.0, - 1);
  
  vec2 sampleDistance = vec2(0.005, 0.0);
  
  vec3 colourmap;
  
  float fx = bumpMap(sampleDistance.xy, 0.2);
  float fy = bumpMap(sampleDistance.yx, 0.2);
  float f = bumpMap(vec2(0.0), 0.2, colourmap);
  
  distortion = f;
  
  fx = (fx - f) / sampleDistance.x;
  fy = (fy - f) / sampleDistance.x;
  normal = normalize(normal + vec3(fx, fy, 0) * 0.2);
  
  // Holy fuck balls, fresnel!
  // specular = max(0.0, min(1.0, bias + scale * (1.0 + length(camPos-sp * surfNormal)) * power));
  float shade = bias + (scale * pow(1.0 + dot(normalize(surfacePos - vec3(uv, - 3.0)), normal), power));
  
  vec3 lightV = lightPos - surfacePos;
  float lightDist = max(length(lightV), 0.001);
  lightV /= lightDist;
  
  //vec3 lightColour = vec3(.8, .8, 1.);
  vec3 lightColour = vec3(1.0); // 白にする
  
  float shininess = 0.8;
  float brightness = 1.0;
  
  float falloff = 0.1;
  float attenuation = 1.0 / (1.0 + lightDist * lightDist * falloff);
  
  float diffuse = max(dot(normal, lightV), 0.0);
  float specular = pow(max(dot(reflect(-lightV, normal), - ray), 0.0), 52.0) * shininess;
  
  // vec3 tex = texture2D(u_environment, (reflect(vec3(uv, - 1.0), normal)).xy).rgb;
  vec3 reflect_ray = reflect(vec3(uv, 1.0), normal * 1.0);
  // The reflect ray is the ray wwe use to determine the reflection.
  // We use the UV less the movement (to account for "environment") to the surface normal
  
  vec3 tex = vec3(0.5) - (shade + 0.5);
  // 環境を無効
  // vec3 tex = envMap(reflect_ray, normal, 1.5) * (shade + 0.5); // Fake environment mapping.
  
  vec3 texCol = (vec3(0.5, 0.5, 0.5) + tex * brightness) * 0.5;
  
  float metalness = (1.0 - colourmap.x);
  metalness *= metalness;
  
  vec3 colour = (texCol * (diffuse * vec3(1, 0.97, 0.92) * 2.0 + 0.5) + lightColour * specular * f*2.0 * metalness) * attenuation * 1.5;
  // colour *= 1.5;
  
  // return vec4(shade);
  return vec4(colour, 1.0);
}

void main() {
  
  vec4 fragcolour = vec4(0);
  
  if (u_renderpass) {
    fragcolour = renderRipples();
  }else {
    
    // uv.x += sin(u_time*.5);
    // sample.x += sin(u_time*.05);
    
    float distortion;
    
    // 画像のサイズに合わせて変更
    float imageAspect = u_texture_width / u_texture_height;
    float screenAspect = u_resolution.x / u_resolution.y;
    
    // cover
    // 正規化されたUV（左上が (0,0), 右下が (1,1)）
    vec2 uv01 = gl_FragCoord.xy / u_resolution.xy;
    
    // uvを中心に対称に拡大縮小するように補正
    vec2 correctedUV = (uv01 - 0.5);
    
    // スケーリング比率の計算
    if (imageAspect > screenAspect) {
      // 画像が横長 → 縦にスケーリング
      float scale = screenAspect / imageAspect;
      correctedUV.y /= scale;
    } else {
      // 画像が縦長 → 横にスケーリング
      float scale = imageAspect / screenAspect;
      
      correctedUV.x /= scale;
    }
    
    // cover風にする
    float scale = max(screenAspect / imageAspect, imageAspect / screenAspect);
    correctedUV /= scale;
    // ここまで
    
    correctedUV += 0.5;
    
    // 範囲外をマスク（オプション）
    if (correctedUV.x < 0.0 || correctedUV.x > 1.0 || correctedUV.y < 0.0 || correctedUV.y > 1.0) {
      discard;
    }
    
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / min(u_resolution.y, u_resolution.x);
    vec4 reflections = renderPass(uv, distortion);
    
    vec2 sample = gl_FragCoord.xy / u_resolution.xy;
    // UVを0.0〜1.0に正規化
    //  vec2 uv01 = (gl_FragCoord.xy) / u_resolution.xy;
    
    // float distortion_delta = float(u_time);
    float distortion_delta = 0.5;
    vec4 c1 = texture2D(u_texture, vec2(0.9 * distortion_delta, 0.9 * distortion_delta) - (correctedUV + distortion * distortion_delta)).rgba;
    vec4 c2 = texture2D(u_texture2, vec2(0.9 * distortion_delta, 0.9 * distortion_delta) - (correctedUV + distortion * distortion_delta)).rgba;
    vec4 c3 = texture2D(u_texture3, vec2(0.9 * distortion_delta, 0.9 * distortion_delta) - (correctedUV + distortion * distortion_delta)).rgba;
    
    vec4 c;
    // 時間に応じたmix係数（3〜4秒の間で0→1に変化）
    // if (u_time < 4.0) {
      //   float mixRatio = clamp((u_time - 1.0) / 3.0, 0.0, 1.0);
      
      //   c = mix(c1, c2, mixRatio);
    // }else {
      //   float mixRatio = clamp((u_time - 5.0) / 1.0, 0.0, 1.0);
      
      //   c = mix(c2, c3, mixRatio);
    // }
    
    float mixRatio = fract(u_stage); // 0.0〜1.0 を取り出す（補間用）
    int stage = int(floor(u_stage)); // 遷移段階
    if (stage == 0) {
      c = mix(c1, c2, mixRatio); // 0→1 で c1→c2
    } else if (stage == 1) {
      c = mix(c2, c3, mixRatio); // 0→1 で c2→c3
    } else {
      c = c3;
    }
    
    // c = texture2D(u_texture, (correctedUV)).rgba;
    
    // vec4 c = texture2D(u_texture, vec2(0.9, 0.9) - (correctedUV + distortion)).rgba;
    // vec4 c = texture2D(u_texture, correctedUV).rgba;
    //fragcolour = c * c * c * .4;
    //     fragcolour = c * 0.9 + 0.1 ; // 元のテクスチャをほぼそのまま使う
    
    fragcolour = pow(c, vec4(1.2)) * 1.2;
    fragcolour *= fragcolour;
    fragcolour += (texture2D(u_buffer, sample + 0.03).x) * 0.1 - 0.1;
    fragcolour += reflections * 0.77;
    // fragcolour = texture2D(u_buffer, sample + fragcolour.rg * .005);
    // // fragcolour = vec4(fragcolour.x * fragcolour.x);
  }
  
  gl_FragColor = fragcolour;
}