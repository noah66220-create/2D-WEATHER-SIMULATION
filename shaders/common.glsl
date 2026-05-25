precision highp int;
precision highp isampler2D;

#define PI 3.1415926535897932384626433832795
#define rad2deg 57.2958
#define deg2rad 0.0174533


#define lightHeatingConst 0.000002   // how much a unit of IR or sunlight (W/m2) changes the temperature per iteration

#define standardSunBrightness 1250.; // W/m2

#define maxWaterTemp 40.0

#define waterHeatExchangeRate 0.0002

#define waterHeatCapacity 50.0     // as multiple of airs heat capacity

#define fullGreenSoilMoisture 50.0 // level of soil moisture where vegetation reaches the greenest color

#define fullWhiteSnowHeight 10.0   // snow height at witch full whiteness is displayed and max albedo is achieved
#define snowMassToHeight 0.05

#define snowMeltRate 0.000015


#define ALBEDO_SNOW 0.85        // above 10 cm of snow cover without vegetation
#define ALBEDO_SNOW_FOREST 0.30 // at max vegetation and above 10 cm of snow
#define ALBEDO_FOREST 0.10
#define ALBEDO_DRYSOIL 0.30     // desert sand
#define ALBEDO_WETSOIL 0.15     // above 20 mm of soil moisture
#define ALBEDO_URBAN 0.08
#define ALBEDO_INDUSTRIAL 0.08
#define ALBEDO_RUNWAY 0.04
#define ALBEDO_WATER 0.05

// TEXTURE DESCRIPTIONS AND DEFINES

// base texture: RGBA32F
// .x  Horizontal velocity                              -1.0 to 1.0
// .y  Vertical   velocity                              -1.0 to 1.0
#define VX 0
#define VY 1
#define PRESSURE 2    // Pressure                                          >= 0
#define TEMPERATURE 3 // Temperature in air and water, indicator in wall

// water texture: RGBA32F
#define TOTAL 0         // Vapor + cloud water             >= 0
#define CLOUD 1         // cloud water                     >= 0
#define PRECIPITATION 2 // precipitation in air            >= 0
#define SOIL_MOISTURE 2 // moisture in surface             >= 0
#define SMOKE 3         // smoke/dust in air               >= 0 for smoke/dust
#define SNOW 3          // snow at surface in cm           0 to 40000

// wall texture: RGBA8I
#define TYPE 0 //             walltype:

#define WALLTYPE_INERT 0
#define WALLTYPE_LAND 1
#define WALLTYPE_WATER 2 // lake / sea
#define WALLTYPE_FIRE 3
#define WALLTYPE_URBAN 4
#define WALLTYPE_RUNWAY 5
#define WALLTYPE_INDUSTRIAL 6

#define DISTANCE 1      // manhattan distance to nearest wall                   0 to 127
#define VERT_DISTANCE 2 // height above/below ground. Surface = 0               -127 to 127
#define VEGETATION 3    // vegetation 0 to 127     grass from 0 to 50, trees from 51 to 127


//  light texture: RGBA32F
#define SUNLIGHT 0    // sunlight                                             0 to 1.0
#define NET_HEATING 1 // net heating effect of IR + sun absorbed by smoke
#define IR_DOWN 2     // IR coming down                                       >= 0
#define IR_UP 3       // IR going  up                                         >= 0

// Precipitation mass:
#define WATER 0
#define ICE 1

// Precipitation feedback
#define MASS 0
#define HEAT 1
#define VAPOR 2
// 3 not used

// Lightning Location
// #define POSX 0
// #define POSY 1
#define START_ITERNUM 2
#define INTENSITY 3

// Precipitation deposition
#define RAIN_DEPOSITION 0
#define SNOW_DEPOSITION 1


// Universal Functions
float map_range(float value, float min1, float max1, float min2, float max2) { return min2 + (value - min1) * (max2 - min2) / (max1 - min1); }

float map_rangeC(float value, float min1, float max1, float min2, float max2) { return clamp(map_range(value, min1, max1, min2, max2), min(min2, max2), max(min2, max2)); }

uint hash(uint x)
{
  x += (x << 10u);
  x ^= (x >> 6u);
  x += (x << 3u);
  x ^= (x >> 11u);
  x += (x << 15u);
  return x;
}
float random(float f)
{
  const uint mantissaMask = 0x007FFFFFu;
  const uint one = 0x3F800000u;

  uint h = hash(floatBitsToUint(f));
  h &= mantissaMask;
  h |= one;

  float r2 = uintBitsToFloat(h);
  // return mod(r2 - 1.0, 1.0);
  return fract(r2);
}

float random2d(vec2 s)
{
  const uint mantissaMask = 0x007FFFFFu;
  const uint one = 0x3F800000u;

  uint h = hash(floatBitsToUint(s.x) + hash(floatBitsToUint(s.y)));
  h &= mantissaMask;
  h |= one;

  float r2 = uintBitsToFloat(h);
  return mod(r2, 1.0);
}

float rand2d(vec2 co)
{
  const float a = 12.9898;
  const float b = 78.233;
  const float c = 43758.5453123;
  float dt = dot(co.xy, vec2(a, b));
  float sn = mod(dt, 3.14);
  return fract(sin(sn) * c);
}

// Temperature Functions

float potentialToRealT(float potential) { return potential - texCoord.y * dryLapse; }

float potentialToRealT(float potential, float texCoordY) { return potential - texCoordY * dryLapse; }

float realToPotentialT(float real) { return real + texCoord.y * dryLapse; }

float CtoK(float c) { return c + 273.15; }

float KtoC(float k) { return k - 273.15; }

float dT_saturated(float dTdry,
                   float dTl) // dTl = temperature difference because of latent heat
{
  if (dTl == 0.0)
    return dTdry;
  else {
    float multiplier = dTdry / (dTdry - dTl);

    return dTdry * multiplier;
  }
}
////////////// Water Functions ///////////////
#define wf_devider 250.0 // 250.0 Real water 	230 less steep curve
#define wf_pow 17.0      // 17.0						10
// https://www.geogebra.org/calculator/jc9hkfq4

float maxWater(float T)
{
  return pow((T / wf_devider), wf_pow); // T in Kelvin, w in grams per m^3
}

float dewpoint(float W)
{
  if (W < 0.00001)
    return 0.0;
  else
    return wf_devider * pow(W, 1.0 / wf_pow);
}

float relativeHumd(float T, float W) { return (W / maxWater(T)); }

// interpolation

vec4 textureBilinear32(sampler2D tex, vec2 uv)
{
  vec2 texSize = vec2(textureSize(tex, 0));

  // Convert UV to texel space
  vec2 coord = uv * texSize - 0.5;

  vec2 base = floor(coord);
  vec2 f = coord - base;

  ivec2 i = ivec2(base);

  // Fetch the 4 nearest texels
  vec4 t00 = texelFetch(tex, i + ivec2(0, 0), 0);
  vec4 t10 = texelFetch(tex, i + ivec2(1, 0), 0);
  vec4 t01 = texelFetch(tex, i + ivec2(0, 1), 0);
  vec4 t11 = texelFetch(tex, i + ivec2(1, 1), 0);

  // Bilinear interpolation (full float precision)
  vec4 tx0 = mix(t00, t10, f.x);
  vec4 tx1 = mix(t01, t11, f.x);

  return mix(tx0, tx1, f.y);
}

vec4 bilerp(sampler2D tex, vec2 pos)
{
  vec2 st = pos - 0.5; // calc pixel coordinats

  vec2 ipos = vec2(floor(st));
  vec2 fpos = fract(st);

  ipos /= resolution;
  ipos += texelSize * 0.5;

  vec4 a = texture(tex, ipos);
  vec4 b = texture(tex, ipos + vec2(texelSize.x, 0));
  vec4 c = texture(tex, ipos + vec2(0, texelSize.y));
  vec4 d = texture(tex, ipos + vec2(texelSize.x, texelSize.y));

  float mixAB = fpos.x;
  float mixCD = fpos.x;
  float mixAB_CD = fpos.y;

  return mix(mix(a, b, mixAB), mix(c, d, mixCD), mixAB_CD);
}

vec4 bilerpWall(sampler2D tex, isampler2D wallTex,
                vec2 pos) // prevents sampeling from wall cell
{
  vec2 st = pos - 0.5;    // calc pixel coordinats

  vec2 ipos = vec2(floor(st));
  vec2 fpos = fract(st);

  vec4 a = texture(tex, (ipos + vec2(0.5, 0.5)) / resolution);
  vec4 b = texture(tex, (ipos + vec2(1.5, 0.5)) / resolution);
  vec4 c = texture(tex, (ipos + vec2(0.5, 1.5)) / resolution);
  vec4 d = texture(tex, (ipos + vec2(1.5, 1.5)) / resolution);

  ivec4 wa = texture(wallTex, (ipos + vec2(0.5, 0.5)) / resolution);
  ivec4 wb = texture(wallTex, (ipos + vec2(1.5, 0.5)) / resolution);
  ivec4 wc = texture(wallTex, (ipos + vec2(0.5, 1.5)) / resolution);
  ivec4 wd = texture(wallTex, (ipos + vec2(1.5, 1.5)) / resolution);

  float mixAB = fpos.x;
  float mixCD = fpos.x;
  float mixAB_CD = fpos.y;

  if (wa[DISTANCE] == 0)
    mixAB = 1.;
  else if (wb[DISTANCE] == 0)
    mixAB = 0.;

  if (wc[DISTANCE] == 0)
    mixCD = 1.;
  else if (wd[DISTANCE] == 0)
    mixCD = 0.;

  if (wa[DISTANCE] == 0 && wb[1] == 0)
    mixAB_CD = 1.;
  else if (wc[DISTANCE] == 0 && wd[DISTANCE] == 0)
    mixAB_CD = 0.;

  return mix(mix(a, b, mixAB), mix(c, d, mixCD), mixAB_CD);
}

// ── Monotone cubic interpolation ─────────────────────────────────────────────
// Fritsch-Carlson monotone cubic in 1D.
// v0..v3 are samples at positions -1, 0, 1, 2. t is blend factor in [0,1].
float cubicMono(float v0, float v1, float v2, float v3, float t)
{
  float d0 = (v2 - v0) * 0.5;
  float d1 = (v3 - v1) * 0.5;
  float delta = v2 - v1;

  if (abs(delta) < 0.00001) {
    d0 = 0.0;
    d1 = 0.0;
  } else {
    float alpha = d0 / delta;
    float beta = d1 / delta;
    float r = alpha * alpha + beta * beta;
    if (r > 9.0) {
      float s = 3.0 / sqrt(r);
      d0 = s * alpha * delta;
      d1 = s * beta * delta;
    }
  }

  float t2 = t * t;
  float t3 = t2 * t;
  return v1 * (2.0 * t3 - 3.0 * t2 + 1.0) + d0 * (t3 - 2.0 * t2 + t) + v2 * (-2.0 * t3 + 3.0 * t2) + d1 * (t3 - t2);
}


vec4 textureCubicMonoClamped(sampler2D tex, vec2 uv)
{
  vec2 texSize = vec2(textureSize(tex, 0));
  vec2 coord = uv * texSize - 0.5;
  vec2 base = floor(coord);
  vec2 f = coord - base;
  ivec2 i = ivec2(base);
  ivec2 maxTC = ivec2(texSize) - 1;

  vec4 p[16];
  for (int row = 0; row < 4; row++)
    for (int col = 0; col < 4; col++) {
      ivec2 tc;
      tc.x = int(mod(float(i.x + col - 1), texSize.x)); // wrap horizontally
      tc.y = clamp(i.y + row - 1, 0, maxTC.y);          // clamp vertically
      p[row * 4 + col] = texelFetch(tex, tc, 0);
    }

  vec4 row0 = vec4(cubicMono(p[0].r, p[1].r, p[2].r, p[3].r, f.x), cubicMono(p[0].g, p[1].g, p[2].g, p[3].g, f.x), cubicMono(p[0].b, p[1].b, p[2].b, p[3].b, f.x),
                   cubicMono(p[0].a, p[1].a, p[2].a, p[3].a, f.x));
  vec4 row1 = vec4(cubicMono(p[4].r, p[5].r, p[6].r, p[7].r, f.x), cubicMono(p[4].g, p[5].g, p[6].g, p[7].g, f.x), cubicMono(p[4].b, p[5].b, p[6].b, p[7].b, f.x),
                   cubicMono(p[4].a, p[5].a, p[6].a, p[7].a, f.x));
  vec4 row2 = vec4(cubicMono(p[8].r, p[9].r, p[10].r, p[11].r, f.x), cubicMono(p[8].g, p[9].g, p[10].g, p[11].g, f.x), cubicMono(p[8].b, p[9].b, p[10].b, p[11].b, f.x),
                   cubicMono(p[8].a, p[9].a, p[10].a, p[11].a, f.x));
  vec4 row3 = vec4(cubicMono(p[12].r, p[13].r, p[14].r, p[15].r, f.x), cubicMono(p[12].g, p[13].g, p[14].g, p[15].g, f.x), cubicMono(p[12].b, p[13].b, p[14].b, p[15].b, f.x),
                   cubicMono(p[12].a, p[13].a, p[14].a, p[15].a, f.x));

  vec4 result = vec4(cubicMono(row0.r, row1.r, row2.r, row3.r, f.y), cubicMono(row0.g, row1.g, row2.g, row3.g, f.y), cubicMono(row0.b, row1.b, row2.b, row3.b, f.y),
                     cubicMono(row0.a, row1.a, row2.a, row3.a, f.y));

  // Clamp result to the range of the 2x2 central samples only.
  // These are the samples actually being interpolated between —
  // p[5], p[6], p[9], p[10] in row-major order (row 1-2, col 1-2).
  vec4 cMin = min(min(p[5], p[6]), min(p[9], p[10]));
  vec4 cMax = max(max(p[5], p[6]), max(p[9], p[10]));
  return clamp(result, cMin, cMax);
}


// Returns true if this texel is a wall
bool isWall(isampler2D wallTex, ivec2 tc, ivec2 maxTC)
{
  tc = clamp(tc, ivec2(0), maxTC);
  return texelFetch(wallTex, tc, 0)[DISTANCE] == 0;
}

// Fetch a texel, clamping to edge AND skipping walls.
// If the requested texel is a wall, walk toward the center sample (cx,cy)
// until we find a non-wall texel or give up and return the center.
vec4 fetchSafe(sampler2D tex, isampler2D wallTex, ivec2 tc, ivec2 center, ivec2 maxTC)
{
  tc = clamp(tc, ivec2(0), maxTC);
  if (!isWall(wallTex, tc, maxTC))
    return texelFetch(tex, tc, 0);
  // Fall back to center sample (always the closest valid cell we know about)
  return texelFetch(tex, clamp(center, ivec2(0), maxTC), 0);
}

// Manually apply repeat in X, clamp in Y (matching your wrap settings)
ivec2 wrapTC(ivec2 tc, ivec2 maxTC)
{
  tc.x = int(mod(float(tc.x), float(maxTC.x + 1))); // repeat X
  tc.y = clamp(tc.y, 0, maxTC.y);                   // clamp Y
  return tc;
}

// Fetch with wrap, returning a validity flag via out parameter
vec4 fetchWall(sampler2D tex, isampler2D wallTex, ivec2 tc, ivec2 maxTC, out bool valid)
{
  tc = wrapTC(tc, maxTC);
  valid = (texelFetch(wallTex, tc, 0)[DISTANCE] != 0);
  return texelFetch(tex, tc, 0);
}


// Interpolate a vec4 across a row of 4 samples using cubicMono per channel
vec4 cubicMonoVec4(vec4 s0, vec4 s1, vec4 s2, vec4 s3, float t)
{
  return vec4(cubicMono(s0.r, s1.r, s2.r, s3.r, t), cubicMono(s0.g, s1.g, s2.g, s3.g, t), cubicMono(s0.b, s1.b, s2.b, s3.b, t), cubicMono(s0.a, s1.a, s2.a, s3.a, t));
}

// ── Wrap/clamp helper ─────────────────────────────────────────────────────────
// Repeat in X (matches gl.TEXTURE_WRAP_S = REPEAT),
// clamp in Y  (matches gl.TEXTURE_WRAP_T = CLAMP_TO_EDGE).
// ivec2 wrapTC(ivec2 tc, ivec2 maxTC)
// {
//   tc.x = int(mod(float(tc.x), float(maxTC.x + 1)));
//   tc.y = clamp(tc.y, 0, maxTC.y);
//   return tc;
// }

// ── Wall-aware fetch ──────────────────────────────────────────────────────────
bool isWallTC(isampler2D wallTex, ivec2 tc) { return texelFetch(wallTex, tc, 0)[DISTANCE] == 0; }

// ── Fix a strip of 4 samples so no wall values corrupt the cubic ──────────────
// Strategy:
//   - Outer samples (index 0 and 3) only affect tangents.
//     If a wall, mirror the adjacent inner sample to enforce zero slope at wall.
//   - Inner samples (index 1 and 2) are the actual interpolation endpoints.
//     If a wall, replace with the opposite inner sample (one-sided interpolation).
//   - If both inner samples are walls, fill everything with the nearest outer
//     valid sample, or vec4(0) as last resort.
void fixStrip(inout vec4 s[4], inout bool v[4])
{
  // Both inner samples are walls — full fallback
  if (!v[1] && !v[2]) {
    vec4 fallback = v[0] ? s[0] : (v[3] ? s[3] : vec4(0.0));
    s[0] = s[1] = s[2] = s[3] = fallback;
    v[0] = v[1] = v[2] = v[3] = true; // mark as patched
    return;
  }

  // Fix inner samples first (they define the interpolation range)
  if (!v[1]) {
    s[1] = s[2];
    v[1] = true;
  }
  if (!v[2]) {
    s[2] = s[1];
    v[2] = true;
  }

  // Fix outer samples (they only affect tangents — mirror for zero slope)
  if (!v[0]) {
    s[0] = s[1];
    v[0] = true;
  }
  if (!v[3]) {
    s[3] = s[2];
    v[3] = true;
  }
}

// ── Wall-aware monotone cubic interpolation ───────────────────────────────────
// Drop-in replacement for textureCubicMonoClamped when walls are present.
// - Handles REPEAT in X / CLAMP in Y via wrapTC (texelFetch ignores wrap params)
// - Wall samples are replaced before cubic evaluation (never corrupt tangents)
// - Final result clamped to range of non-wall central 2x2 samples
vec4 textureCubicMonoWall(sampler2D tex, isampler2D wallTex, vec2 fragCoord)
{

  if (texture(wallTex, fragCoord * texelSize)[DISTANCE] < 5)
    return bilerpWall(tex, wallTex, fragCoord);
  else
    return textureCubicMonoClamped(tex, fragCoord * texelSize);


  /*
    vec2 st = uv * resolution - 0.5;
    vec2 base = floor(st);
    vec2 f = st - base;
    ivec2 i = ivec2(base);
    ivec2 maxTC = ivec2(resolution) - 1;

    // ── Fetch 4x4 neighbourhood ───────────────────────────────────────────────
    vec4 p[16];
    bool v[16];
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        ivec2 tc = wrapTC(i + ivec2(col - 1, row - 1), maxTC);
        p[row * 4 + col] = texelFetch(tex, tc, 0);
        v[row * 4 + col] = !isWallTC(wallTex, tc);
      }
    }

    // ── Fix each row in X ─────────────────────────────────────────────────────
    for (int row = 0; row < 4; row++) {
      int b = row * 4;
      vec4 rowS[4] = vec4[4](p[b], p[b + 1], p[b + 2], p[b + 3]);
      bool rowV[4] = bool[4](v[b], v[b + 1], v[b + 2], v[b + 3]);
      fixStrip(rowS, rowV);
      p[b] = rowS[0];
      p[b + 1] = rowS[1];
      p[b + 2] = rowS[2];
      p[b + 3] = rowS[3];
      // Note: do NOT update v[] here — column pass uses original wall flags,
      // not the patched values, to independently decide column fixes.
    }

    // ── Fix each column in Y (using original v[] flags) ───────────────────────
    for (int col = 0; col < 4; col++) {
      vec4 colS[4] = vec4[4](p[col], p[4 + col], p[8 + col], p[12 + col]);
      bool colV[4] = bool[4](v[col], v[4 + col], v[8 + col], v[12 + col]);
      fixStrip(colS, colV);
      p[col] = colS[0];
      p[4 + col] = colS[1];
      p[8 + col] = colS[2];
      p[12 + col] = colS[3];
    }

    // ── Cubic interpolation on fully-patched samples ──────────────────────────
    vec4 row0 = cubicMonoVec4(p[0], p[1], p[2], p[3], f.x);
    vec4 row1 = cubicMonoVec4(p[4], p[5], p[6], p[7], f.x);
    vec4 row2 = cubicMonoVec4(p[8], p[9], p[10], p[11], f.x);
    vec4 row3 = cubicMonoVec4(p[12], p[13], p[14], p[15], f.x);
    vec4 result = cubicMonoVec4(row0, row1, row2, row3, f.y);

    // ── Clamp to range of non-wall central 2x2 samples ───────────────────────
    // Central samples are p[5], p[6], p[9], p[10] (row 1-2, col 1-2)
    // Use original v[] flags — we want the physical data range, not patched values
    vec4 cMin = vec4(1e9);
    vec4 cMax = vec4(-1e9);
    int centralIdx[4] = int[4](5, 6, 9, 10);
    for (int k = 0; k < 4; k++) {
      if (v[centralIdx[k]]) {
        cMin = min(cMin, p[centralIdx[k]]);
        cMax = max(cMax, p[centralIdx[k]]);
      }
    }
    // Full wall fallback (shouldn't happen if you don't advect from inside walls)
    if (cMin.r > 1e8)
      return p[5];

    return clamp(result, cMin, cMax);
    */
}


#define IR_constant 5.670374419 // ×10−8

float IR_emitted(float T)
{
  return pow(T * 0.01, 4.) * IR_constant; // Stefan–Boltzmann law
}

float IR_temp(float IR) // inversed Stefan–Boltzmann law
{
  return pow(IR / IR_constant, 1. / 4.) * 100.0;
}

float absHorizontalDist(float a, float b) // for wrapping horizontal position around simulation border
{
  return min(min(abs(a - b), abs(1.0 + a - b)), 1.0 - a + b);
}
/*
float realMod(float a, float b)
{
    // proper modulo to handle negative numbers
    return mod(mod(a, b) + b, b);
}
*/


// new hash funtions:


// Standard 2x2 hash algorithm.
vec2 hash22(vec2 p, float seed)
{
  float n = sin(dot(p, vec2(41, 289)));
  p = fract(vec2(2097152, 262144) * n);
  return cos(p * 6.283 + seed * 2.);
  return abs(fract(p + seed * .5) - .5) * 4. - 1.;  // Snooker.
  return abs(cos(p * 6.283 + seed * 2.)) * 2. - 1.; // Bounce.
}

float simplesque2D(vec2 p, float seed)
{
  vec2 s = floor(p + (p.x + p.y) * .3660254); // Skew the current point.
  p -= s - (s.x + s.y) * .2113249;            // Vector to unskewed base vertice.

  // Clever way to perform an "if" statement to determine which of two triangles we need.
  float i = p.x < p.y ? 1. : 0.; // Apparently, faster than: step(p.x, p.y);

  vec2 ioffs = vec2(1. - i, i);  // Vertice offset, based on above.

  // Vectors to the other two triangle vertices.
  vec2 p1 = p - ioffs + .2113249, p2 = p - .5773502;

  // Vector to hold the falloff value of the current pixel with respect to each vertice.
  vec3 d = max(.5 - vec3(dot(p, p), dot(p1, p1), dot(p2, p2)), 0.); // Range [0, 0.5]

  d *= d * d * 12.;                                                 //(2*2*2*1.5)
  // d *= d*d*d*36.;

  vec3 w = vec3(dot(hash22(s, seed), p), dot(hash22(s + ioffs, seed), p1), dot(hash22(s + 1., seed), p2));
  return .5 + dot(w, d); // Range [0, 1]... Hopefully. Needs more attention.
}

float func2D(vec2 p, float seed) { return simplesque2D(p * 4., seed) * .66 + simplesque2D(p * 8., seed) * 0.34; }


// src: https://www.shadertoy.com/view/WttXWX

// --- choose one:
// #define hashi(x) lowbias32(x)
// #define hashi(x) triple32(x)

// #define hash(x) (float(hashi(x)) / float(0xffffffffU))


// bias: 0.17353355999581582 ( very probably the best of its kind )
uint lowbias32(uint x)
{
  x ^= x >> 16;
  x *= 0x7feb352dU;
  x ^= x >> 15;
  x *= 0x846ca68bU;
  x ^= x >> 16;
  return x;
}

// bias: 0.020888578919738908 = minimal theoretic limit
uint triple32(uint x)
{
  x ^= x >> 17;
  x *= 0xed5ad4bbU;
  x ^= x >> 11;
  x *= 0xac4c1b51U;
  x ^= x >> 15;
  x *= 0x31848babU;
  x ^= x >> 14;
  return x;
}

float hash2(int x) { return float(triple32(uint(x))) / float(0xffffffffU); }


// float h = hash( V.x + hashi(V.y) ); // clean 2D hash
//  float h = hash( V.x + (V.y<<16) );  // 2D hash (should be ok too )

float rand2(vec2 s)
{
  // return hash( x + hashi(y) ); // clean 2D hash
  return hash2(int(s.x * 379071.) + int(s.y * 756398.) << 16); // 2D hash (should be ok too )
}

// Color Functions

vec3 hsv2rgb(vec3 c)
{
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 sunColor(float scattering) // 0.0 = white     0.5 = orange     1.0 = red
{
  float val = 1.0 - scattering;
  return hsv2rgb(vec3(0.015 + val * 0.15, min(2.0 - val * 2.0, 1.), 1.));
}