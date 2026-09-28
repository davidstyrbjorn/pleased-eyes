#version 330 core

out vec4 finalColor;
in vec2 fragTexCoord;

uniform float uTime;
uniform vec2  uResolution;

#define time uTime
const float noiseScale = 14.0;
const float cellSize = 1.0;

#define morphPhase (uTime*0.45)
#define spinPhase (uTime*0.0)
const float wanderRadius = 0.7;
#define scrollSpeed vec2(0.5, 0.15)
const vec2 loopD = vec2(0.0, 0.0);
const float jitter = 0.9;
const float minkowskiP = 3.0;
const float starPoints = 11.0;
const float starDepth = 0.0;
const float cellStretch = 0.8;
const float cellAngle = 112.5;
const float cellRadius = 1.3;
const float smoothK = 0.3;
const float edgeSharpen = 2.0;
const float ringCount = 2.0;
const float octaves = 6.0;
const float gain = 0.3;

const vec4 PALETTE[110] = vec4[110](
  vec4(0.00198346,0.000563923,0.00338355,1.0),
  vec4(0.00270539,0.000769177,0.00461508,1.0),
  vec4(0.00412604,0.00117309,0.00703854,1.0),
  vec4(0.00619181,0.00176041,0.0105625,1.0),
  vec4(0.00881353,0.0025058,0.0150348,1.0),
  vec4(0.0118728,0.00337559,0.0202536,1.0),
  vec4(0.0152408,0.00433316,0.0259991,1.0),
  vec4(0.0188011,0.00534538,0.0320724,1.0),
  vec4(0.0224653,0.00638716,0.0383232,1.0),
  vec4(0.0261776,0.00744262,0.0446559,1.0),
  vec4(0.0299085,0.00850335,0.0510203,1.0),
  vec4(0.0336451,0.00956573,0.0573946,1.0),
  vec4(0.0373832,0.0106285,0.0637713,1.0),
  vec4(0.0411215,0.0116914,0.0701484,1.0),
  vec4(0.0448598,0.0127542,0.0765256,1.0),
  vec4(0.0485981,0.0138171,0.0829027,1.0),
  vec4(0.0523364,0.0148799,0.0892798,1.0),
  vec4(0.0560748,0.0159428,0.095657,1.0),
  vec4(0.0598131,0.0170056,0.102034,1.0),
  vec4(0.0635514,0.0180685,0.108411,1.0),
  vec4(0.0672897,0.0191313,0.114788,1.0),
  vec4(0.071028,0.0201942,0.121165,1.0),
  vec4(0.0747664,0.021257,0.127543,1.0),
  vec4(0.0785047,0.0223199,0.13392,1.0),
  vec4(0.082243,0.0233827,0.140297,1.0),
  vec4(0.0859813,0.0244456,0.146674,1.0),
  vec4(0.0897196,0.0255084,0.153051,1.0),
  vec4(0.0934579,0.0265713,0.159428,1.0),
  vec4(0.0971963,0.0276341,0.165805,1.0),
  vec4(0.100935,0.028697,0.172183,1.0),
  vec4(0.104673,0.0297598,0.17856,1.0),
  vec4(0.108411,0.0308227,0.184937,1.0),
  vec4(0.11215,0.0318855,0.191314,1.0),
  vec4(0.115888,0.0329484,0.197691,1.0),
  vec4(0.119626,0.0340112,0.204068,1.0),
  vec4(0.123364,0.0350741,0.210445,1.0),
  vec4(0.127103,0.0361369,0.216822,1.0),
  vec4(0.130841,0.0371998,0.2232,1.0),
  vec4(0.134579,0.0382626,0.229577,1.0),
  vec4(0.138318,0.0393255,0.235954,1.0),
  vec4(0.142056,0.0403883,0.242331,1.0),
  vec4(0.145794,0.0414512,0.248708,1.0),
  vec4(0.149533,0.042514,0.255085,1.0),
  vec4(0.153271,0.0435769,0.261462,1.0),
  vec4(0.157009,0.0446397,0.267839,1.0),
  vec4(0.160748,0.0457026,0.274217,1.0),
  vec4(0.164486,0.0467654,0.280594,1.0),
  vec4(0.168224,0.0478283,0.286971,1.0),
  vec4(0.171963,0.0488911,0.293348,1.0),
  vec4(0.175701,0.049954,0.299725,1.0),
  vec4(0.179439,0.0510168,0.306102,1.0),
  vec4(0.183178,0.0520797,0.312479,1.0),
  vec4(0.186916,0.0531425,0.318857,1.0),
  vec4(0.190654,0.0542054,0.325234,1.0),
  vec4(0.194393,0.0552682,0.331611,1.0),
  vec4(0.198131,0.0563311,0.337988,1.0),
  vec4(0.201869,0.0573939,0.344365,1.0),
  vec4(0.205607,0.0584568,0.350742,1.0),
  vec4(0.209346,0.0595196,0.357119,1.0),
  vec4(0.213084,0.0605825,0.363496,1.0),
  vec4(0.216822,0.0616453,0.369874,1.0),
  vec4(0.220561,0.0627082,0.376251,1.0),
  vec4(0.224299,0.063771,0.382628,1.0),
  vec4(0.228037,0.0648339,0.389005,1.0),
  vec4(0.231776,0.0658967,0.395382,1.0),
  vec4(0.235514,0.0669596,0.401759,1.0),
  vec4(0.239252,0.0680224,0.408136,1.0),
  vec4(0.242991,0.0690853,0.414514,1.0),
  vec4(0.246729,0.0701481,0.420891,1.0),
  vec4(0.250467,0.071211,0.427268,1.0),
  vec4(0.254206,0.0722738,0.433645,1.0),
  vec4(0.257944,0.0733367,0.440022,1.0),
  vec4(0.261682,0.0743995,0.446399,1.0),
  vec4(0.265421,0.0754624,0.452776,1.0),
  vec4(0.269159,0.0765252,0.459153,1.0),
  vec4(0.272897,0.0775881,0.465531,1.0),
  vec4(0.276636,0.0786509,0.471908,1.0),
  vec4(0.280374,0.0797138,0.478285,1.0),
  vec4(0.284112,0.0807766,0.484662,1.0),
  vec4(0.28785,0.0818395,0.491039,1.0),
  vec4(0.291589,0.0829023,0.497416,1.0),
  vec4(0.295327,0.0839652,0.503793,1.0),
  vec4(0.320293,0.116395,0.521398,1.0),
  vec4(0.34526,0.148824,0.539003,1.0),
  vec4(0.370226,0.181254,0.556608,1.0),
  vec4(0.395192,0.213684,0.574214,1.0),
  vec4(0.420158,0.246113,0.591819,1.0),
  vec4(0.445125,0.278543,0.609424,1.0),
  vec4(0.470091,0.310973,0.627029,1.0),
  vec4(0.495057,0.343402,0.644634,1.0),
  vec4(0.520024,0.375832,0.662239,1.0),
  vec4(0.54499,0.408262,0.679844,1.0),
  vec4(0.569956,0.440691,0.69745,1.0),
  vec4(0.594922,0.473121,0.715055,1.0),
  vec4(0.619889,0.50555,0.73266,1.0),
  vec4(0.644855,0.53798,0.750265,1.0),
  vec4(0.669821,0.57041,0.76787,1.0),
  vec4(0.694788,0.602839,0.785475,1.0),
  vec4(0.719754,0.635269,0.80308,1.0),
  vec4(0.74472,0.667699,0.820686,1.0),
  vec4(0.769686,0.700128,0.838291,1.0),
  vec4(0.794653,0.732558,0.855896,1.0),
  vec4(0.819619,0.764988,0.873501,1.0),
  vec4(0.844585,0.797417,0.891106,1.0),
  vec4(0.869552,0.829847,0.908711,1.0),
  vec4(0.894518,0.862276,0.926316,1.0),
  vec4(0.919484,0.894706,0.943922,1.0),
  vec4(0.94445,0.927136,0.961527,1.0),
  vec4(0.969417,0.959565,0.979132,1.0),
  vec4(0.994383,0.991995,0.996737,1.0)
);
vec4 paletteLookup(float x){
  int i = clamp(int(clamp(x,0.0,1.0)*256.0),0,255);
  return PALETTE[clamp(int(float(i)/255.0*110.0),0,109)];
}

#define TAU 6.28318530718
#define MAX_OCTAVES 10
#define WANDER_SPD_MIN 0.4
#define WANDER_SPD_MAX 1.6

vec2 latticeOffset(vec2 cell) {
    float row = floor(cell.y);
    return vec2(0.0);
}

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

float tnoise(float seed, float t, float per) {
    float v = 0.0, a = 0.5, n = 0.0;
    for (int i = 0; i < 2; i++) {
        float ii = floor(t), f = fract(t);
        f = f * f * (3.0 - 2.0 * f);
        float i0 = ii, i1 = ii + 1.0;
        if (per > 0.5) { i0 = mod(i0, per); i1 = mod(i1, per); }
        v += a * mix(hash2(vec2(seed, i0)).x, hash2(vec2(seed, i1)).x, f);
        n += a; t = t * 2.0 + 1.3; seed = seed * 1.7 + 3.1; a *= 0.5; per *= 2.0;
    }
    return v / n;
}

vec2 wrapCell(vec2 cell, float angN, vec2 d) {
    if (angN > 0.5) cell.x = mod(cell.x, angN);
    
    return cell;
}


float metricDist(vec2 d, float ang) {
    float s = sin(ang), c = cos(ang);
    d = mat2(c, -s, s, c) * d;
    d.x *= cellStretch; d.y /= cellStretch;
    float p  = max(minkowskiP, 0.1);
    float md = pow(pow(abs(d.x), p) + pow(abs(d.y), p), 1.0 / p);
    return md * (1.0 + starDepth * cos(starPoints * atan(d.y, d.x)));
}


float cellSpin(vec2 cell) {
    float turns = cellAngle / 360.0;
    turns += spinPhase;
    return -turns * TAU;
}

float smin(float a, float b, float k) {
    if (k <= 0.0) return min(a, b);
    float h = clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
    return mix(a, b, h) - k * h * (1.0 - h);
}

void consider(float d, inout float f1, inout float f2) {
    if      (d < f1) f2 = f1;
    else if (d < f2) f2 = d;
    f1 = smin(f1, d, smoothK);
}

float comboValue(float f1, float f2) {
    float s = 1.0 / max(cellRadius, 0.001);
    f1 *= s; f2 *= s;
    float v;
    v = sqrt(max(1.0 - f1 * f1, 0.0));
    v = clamp(v, 0.0, 1.0);
    v = pow(v, edgeSharpen);
    v = 0.5 - 0.5 * cos(v * ringCount * TAU);
    return clamp(v, 0.0, 1.0);
}

vec2 warpUV(vec2 uv) {
    return uv;
}

vec2 rotateUV(vec2 uv) {
    return uv;
}

#define CELL_EMPTY_LO 4.0
#define CELL_EMPTY_HI 7.0
#define CELL_EMPTY_VALUE 1.0

vec2 cBaseMouse;


float cellFinish(float f1, float f2, bool doCells) {
    float v = comboValue(f1, f2);
    if (doCells) v = mix(v, CELL_EMPTY_VALUE, smoothstep(CELL_EMPTY_LO, CELL_EMPTY_HI, f1));
    
    return v;
}

float cellWander(vec2 p, float angN, vec2 d, bool isBase) {

    vec2 ip = floor(p), fp = fract(p);
    float f1 = 8.0, f2 = 8.0;
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            vec2 g    = vec2(float(i), float(j));
            vec2 cell = wrapCell(ip + g, angN, d);
            vec2 rnd  = hash2(cell);
            vec2 base = mix(vec2(0.5), rnd, jitter);
            vec2 rate = mix(vec2(WANDER_SPD_MIN), vec2(WANDER_SPD_MAX), hash2(cell + 37.0));

            vec2 per = vec2(0.0);
            
            vec2 mov  = wanderRadius * (2.0 * vec2(tnoise(rnd.x, morphPhase * rate.x, per.x),
                                                   tnoise(rnd.y + 11.0, morphPhase * rate.y, per.y)) - 1.0);
            vec2 pt   = g + base + mov;
            pt += latticeOffset(cell) * (1.0 - jitter);
            
            float d = metricDist(pt - fp, cellSpin(cell));
            
            consider(d, f1, f2);
        }
    }
    
    return cellFinish(f1, f2, false);
}

float cellEval(vec2 p, float angN, vec2 d, bool isBase) {
    return cellWander(p, angN, d, isBase);
}

float cellFBM(vec2 p, float angN) {
    float v = 0.0, a = 0.5, norm = 0.0;
    vec2  d = loopD;
    int oct = int(octaves + 0.5);
    for (int i = 0; i < MAX_OCTAVES; i++) {
        if (i >= oct) break;
        v    += a * cellEval(p, angN, d, i == 0);
        norm += a;
        p     = p * 2.0 + vec2(5.3, 1.7);
        a    *= gain;
        if (angN > 0.5) angN *= 2.0;

        d    *= 2.0;
    }
    return v / norm;
}

vec4 shade(vec2 screen_coords) {
    vec2 block = floor((screen_coords) / cellSize) * cellSize;
    vec2 uv0   = warpUV(block / uResolution);
    float mzAdd = 0.0, valAdd = 0.0;
    vec2 uvDisp = vec2(0.0);

    vec2 uv = rotateUV(uv0 + uvDisp);

    vec2  p;
    float angN = 0.0;
    {
        p = uv * noiseScale + time * scrollSpeed;
    }
    p.y *= 1.0;

    float v = cellFBM(p, angN);
    v = clamp(v + valAdd, 0.0, 1.0);

    return paletteLookup(v);
}


void main(){
  vec4 c = shade(vec2(gl_FragCoord.x, uResolution.y - gl_FragCoord.y));
  finalColor = vec4(c.rgb * c.a, 1.0);
}