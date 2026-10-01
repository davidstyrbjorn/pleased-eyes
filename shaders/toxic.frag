#version 330 core
out vec4 fragColor;
uniform float uTime;
uniform vec2  uResolution;

#define time uTime
const float noiseScale = 9.0;
#define screenSize uResolution
#define sampleOffset vec2(0.0)
#define renderSize uResolution
const float cellSize = 1.0;

#define morphPhase (uTime*0.2)
#define spinPhase (uTime*0.0)
const float orbitRadius = 0.5;
#define scrollSpeed vec2(0.0, 0.0)
const vec2 loopD = vec2(0.0, 0.0);
const float jitter = 0.7;
const float minkowskiP = 2.0;
const float starPoints = 5.0;
const float starDepth = 0.0;
const float cellStretch = 1.2;
const float cellAngle = 0.0;
const float cellRadius = 0.9;
const float smoothK = 0.0;
const float octaves = 6.0;
const float gain = 0.5;
const float warpStrength = 0.75;
const float rippleFreq = 50.0;
const float pinchStrength = -0.6;
#define warpPhase (uTime*0.0)

const vec4 PALETTE[110] = vec4[110](
  vec4(0.356328,0.513717,0.0502017,1.0),
  vec4(0.350215,0.519648,0.0539687,1.0),
  vec4(0.344156,0.525579,0.05772,1.0),
  vec4(0.338149,0.53151,0.0614562,1.0),
  vec4(0.332192,0.537441,0.065178,1.0),
  vec4(0.326282,0.543373,0.068886,1.0),
  vec4(0.320418,0.549304,0.0725806,1.0),
  vec4(0.314599,0.555235,0.0762625,1.0),
  vec4(0.308821,0.561166,0.0799321,1.0),
  vec4(0.303084,0.567097,0.0835899,1.0),
  vec4(0.297387,0.573029,0.0872363,1.0),
  vec4(0.291727,0.57896,0.0908718,1.0),
  vec4(0.286103,0.584891,0.0944967,1.0),
  vec4(0.280514,0.590822,0.0981115,1.0),
  vec4(0.27496,0.596753,0.101716,1.0),
  vec4(0.269437,0.602684,0.105312,1.0),
  vec4(0.263946,0.608616,0.108898,1.0),
  vec4(0.258485,0.614547,0.112476,1.0),
  vec4(0.253054,0.620478,0.116045,1.0),
  vec4(0.247651,0.626409,0.119606,1.0),
  vec4(0.242275,0.63234,0.123159,1.0),
  vec4(0.236926,0.638271,0.126704,1.0),
  vec4(0.231602,0.644203,0.130242,1.0),
  vec4(0.226303,0.650134,0.133773,1.0),
  vec4(0.221028,0.656065,0.137297,1.0),
  vec4(0.215776,0.661996,0.140814,1.0),
  vec4(0.210546,0.667927,0.144324,1.0),
  vec4(0.205338,0.673858,0.147828,1.0),
  vec4(0.200151,0.67979,0.151326,1.0),
  vec4(0.194985,0.685721,0.154819,1.0),
  vec4(0.189839,0.691652,0.158305,1.0),
  vec4(0.184711,0.697583,0.161786,1.0),
  vec4(0.179603,0.703514,0.165261,1.0),
  vec4(0.174512,0.709445,0.168731,1.0),
  vec4(0.16944,0.715377,0.172196,1.0),
  vec4(0.164384,0.721308,0.175656,1.0),
  vec4(0.164384,0.721308,0.175656,1.0),
  vec4(0.164384,0.721308,0.175656,1.0),
  vec4(0.164384,0.721308,0.175656,1.0),
  vec4(0.164384,0.721308,0.175656,1.0),
  vec4(0.164384,0.721308,0.175656,1.0),
  vec4(0.164384,0.721308,0.175656,1.0),
  vec4(0.164384,0.721308,0.175656,1.0),
  vec4(0.164384,0.721308,0.175656,1.0),
  vec4(0.164384,0.721308,0.175656,1.0),
  vec4(0.164384,0.721308,0.175656,1.0),
  vec4(0.161348,0.717554,0.174735,1.0),
  vec4(0.158308,0.713799,0.173813,1.0),
  vec4(0.155265,0.710045,0.172892,1.0),
  vec4(0.152217,0.706291,0.171971,1.0),
  vec4(0.149165,0.702537,0.17105,1.0),
  vec4(0.146108,0.698783,0.17013,1.0),
  vec4(0.143047,0.695028,0.16921,1.0),
  vec4(0.139982,0.691274,0.16829,1.0),
  vec4(0.136912,0.68752,0.16737,1.0),
  vec4(0.133838,0.683766,0.166451,1.0),
  vec4(0.130758,0.680012,0.165531,1.0),
  vec4(0.127674,0.676257,0.164612,1.0),
  vec4(0.124585,0.672503,0.163694,1.0),
  vec4(0.121491,0.668749,0.162776,1.0),
  vec4(0.118391,0.664995,0.161857,1.0),
  vec4(0.115287,0.66124,0.16094,1.0),
  vec4(0.112177,0.657486,0.160022,1.0),
  vec4(0.109062,0.653732,0.159105,1.0),
  vec4(0.105941,0.649978,0.158188,1.0),
  vec4(0.102814,0.646224,0.157272,1.0),
  vec4(0.0996819,0.642469,0.156356,1.0),
  vec4(0.0965436,0.638715,0.15544,1.0),
  vec4(0.0933992,0.634961,0.154524,1.0),
  vec4(0.0902487,0.631207,0.153609,1.0),
  vec4(0.0870919,0.627453,0.152694,1.0),
  vec4(0.0839286,0.623698,0.15178,1.0),
  vec4(0.0807587,0.619944,0.150866,1.0),
  vec4(0.0775822,0.61619,0.149952,1.0),
  vec4(0.0743987,0.612436,0.149039,1.0),
  vec4(0.0712082,0.608682,0.148126,1.0),
  vec4(0.0680105,0.604927,0.147214,1.0),
  vec4(0.0648055,0.601173,0.146302,1.0),
  vec4(0.061593,0.597419,0.14539,1.0),
  vec4(0.0583727,0.593665,0.144479,1.0),
  vec4(0.0551446,0.589911,0.143568,1.0),
  vec4(0.0519085,0.586156,0.142658,1.0),
  vec4(0.0486641,0.582402,0.141748,1.0),
  vec4(0.0454113,0.578648,0.140838,1.0),
  vec4(0.0421499,0.574894,0.139929,1.0),
  vec4(0.0388796,0.571139,0.139021,1.0),
  vec4(0.0356003,0.567385,0.138113,1.0),
  vec4(0.0323117,0.563631,0.137206,1.0),
  vec4(0.0290136,0.559877,0.136299,1.0),
  vec4(0.0265823,0.556123,0.136013,1.0),
  vec4(0.0265823,0.552368,0.137436,1.0),
  vec4(0.0265823,0.548614,0.138836,1.0),
  vec4(0.0265823,0.54486,0.140213,1.0),
  vec4(0.0265823,0.541106,0.141568,1.0),
  vec4(0.0265823,0.537352,0.142899,1.0),
  vec4(0.0265823,0.533597,0.144207,1.0),
  vec4(0.0265823,0.529843,0.145491,1.0),
  vec4(0.0265823,0.526089,0.146751,1.0),
  vec4(0.0265823,0.522335,0.147988,1.0),
  vec4(0.0265823,0.518581,0.149201,1.0),
  vec4(0.0265823,0.514826,0.150389,1.0),
  vec4(0.0265823,0.514826,0.150389,1.0),
  vec4(0.0265823,0.514826,0.150389,1.0),
  vec4(0.0265823,0.514826,0.150389,1.0),
  vec4(0.0265823,0.514826,0.150389,1.0),
  vec4(0.0265823,0.514826,0.150389,1.0),
  vec4(0.0265823,0.514826,0.150389,1.0),
  vec4(0.0265823,0.514826,0.150389,1.0),
  vec4(0.0265823,0.514826,0.150389,1.0),
  vec4(0.0265823,0.514826,0.150389,1.0)
);
vec4 paletteLookup(float x){
  int i = clamp(int(clamp(x,0.0,1.0)*256.0),0,255);
  return PALETTE[clamp(int(float(i)/255.0*110.0),0,109)];
}

#define TAU 6.28318530718
#define MAX_OCTAVES 10

vec2 frameC(vec2 uv) {
    vec2 r = renderSize;
    return (uv - 0.5) * screenSize / r.y;
}
vec2 frameUV(vec2 c) {
    vec2 r = renderSize;
    return 0.5 + c * r.y / screenSize;
}

vec2 latticeOffset(vec2 cell) {
    float row = floor(cell.y);
    return vec2(0.0);
}

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
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
    v = f1 * 1.4;
    v = clamp(v, 0.0, 1.0);

    return clamp(v, 0.0, 1.0);
}

#define RIPPLE_AMP  0.05
#define PINCH_R     0.8
#define PINCH_K     0.9
#define PINCH_PULSE 0.5

vec2 warpUV(vec2 uv) {
    
    {
        vec2  c   = frameC(uv);
        float r   = length(c);
        vec2  dir = r > 1e-4 ? c / r : vec2(0.0);
        c += dir * warpStrength * RIPPLE_AMP * sin(r * rippleFreq - warpPhase * TAU);
        return frameUV(c);
    }
    vec2  c   = frameC(uv);
    float r   = length(c);
    if (r > 1e-5) {
        float k  = pinchStrength * (1.0 + PINCH_PULSE * sin(warpPhase * TAU));
        float rn = min(r / PINCH_R, 1.0);
        float factor;
        if (k >= 0.0) {
            factor = pow(rn, k * PINCH_K);
        } else {
            factor = 1.0 + (-k) * PINCH_K * (1.0 - rn * rn); 
        }
        c *= factor;
    }
    return frameUV(c);
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

float cellOrbit(vec2 p, float angN, vec2 d, bool isBase) {

    vec2 ip = floor(p), fp = fract(p);
    float f1 = 8.0, f2 = 8.0;
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            vec2 g    = vec2(float(i), float(j));
            vec2 cell = wrapCell(ip + g, angN, d);
            vec2 rnd  = hash2(cell);
            vec2 anim = 0.5 + orbitRadius * sin(morphPhase * TAU + rnd * TAU);
            vec2 pt   = g + mix(vec2(0.5), anim, jitter);
            pt += latticeOffset(cell) * (1.0 - jitter);
            
            float d = metricDist(pt - fp, cellSpin(cell));
            
            consider(d, f1, f2);
        }
    }
    
    return cellFinish(f1, f2, false);
}

float cellEval(vec2 p, float angN, vec2 d, bool isBase) {
    return cellOrbit(p, angN, d, isBase);
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
    vec2 block = floor((screen_coords + sampleOffset) / cellSize) * cellSize;
    vec2 uv0   = warpUV(block / screenSize);
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
  fragColor = vec4(c.rgb * c.a, 1.0);
}