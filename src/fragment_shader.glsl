#version 330 core
precision mediump float;

out vec4 FragColor;

uniform mat4 view;
uniform samplerCube skybox;
uniform vec2 resolution;

uniform vec3 cameraPos;
uniform vec3 bhPos;
uniform float M;
uniform float R;

in vec2 coordPos;

vec2 fade(vec2 t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float grad(vec2 hash, vec2 p) {
    return dot(hash, p);
}

vec2 random2(vec2 st) {
    st = vec2(dot(st, vec2(127.1, 311.7)),
              dot(st, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(st) * 43758.5453123);
}

float perlinNoise(vec2 p) {
    vec2 pi = floor(p);
    vec2 pf = fract(p);

    vec2 bl = random2(pi + vec2(0.0, 0.0));
    vec2 br = random2(pi + vec2(1.0, 0.0));
    vec2 tl = random2(pi + vec2(0.0, 1.0));
    vec2 tr = random2(pi + vec2(1.0, 1.0));

    vec2 f = fade(pf);

    float b = mix(grad(bl, pf - vec2(0.0, 0.0)),
                  grad(br, pf - vec2(1.0, 0.0)), f.x);
    float t = mix(grad(tl, pf - vec2(0.0, 1.0)),
                  grad(tr, pf - vec2(1.0, 1.0)), f.x);

    return 0.5 + 0.5 * mix(b, t, f.y); // [0,1] output
}

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    float aspectRatio = resolution.x / resolution.y;
    vec3 dir = normalize(vec3(coordPos.x * aspectRatio, coordPos.y, -0.8));
    dir = mat3(view) * dir;
    
    float r_min = 3.0 * R;
    float r_max = 10.0 * R;
    float height = 0.2;

    int MAX_ITER = 300;
    float R_LIMIT = 40.0;
    bool captured = false;
    bool disk = false;
    vec3 diskColor = vec3(0.0);
    float diskAlpha = 0.0;

    float base_dt = 0.15;
    
    vec3 photonPos = cameraPos;

    for (int i = 0; i < MAX_ITER; i++) {

        vec3 r = photonPos - bhPos;
        float rmag = length(r);

        if (rmag < R) {
            captured = true;
            break;
        } else if (rmag > R_LIMIT) {
            break;
        }

        if (rmag > r_min && rmag < r_max && abs(r.y) < 0.5 * height)
        {
            float diskmag = length(r.xz);
            float theta = atan(r.z, r.x);
            vec2 noiseCoord = vec2(diskmag * 2.0, theta * 5.0);
            float noiseValue = perlinNoise(noiseCoord);

            float t = (rmag - r_min) / (r_max - r_min);
            //float alpha = (1.0 - t) * noiseValue;
            //float alpha = ((1.0 - t) + noiseValue) * 0.5;
            //float alpha = min((1.0 - t) + noiseValue, 1.0) * noiseValue;
            float alpha = (1.0 - t) * ((1.0 - t) + noiseValue) * 0.5;
            if (alpha > diskAlpha) {
                diskColor = mix(vec3(1.0, 1.0, 0.0), vec3(1.0, 0.2, 0.0), t);
                diskAlpha = alpha;
                FragColor = vec4(diskColor, 1.0);
                disk = true;
            }
        }  

        vec3 r_dir = r / rmag;

        float rmag2 = rmag * rmag;
        //float RR = 10.0 * R * R;
        float RR = r_max * r_max;
        //float rmag3 = rmag * rmag * rmag;

        float r_dot = dot(-r_dir, dir);
        if (r_dot * R < -2.0) {
            break;
        }

        //float dt = clamp(rmag2 / RR * base_dt, base_dt, 1.0);
        //float dt = max(rmag2 / RR - 1.0, 0.0) + base_dt;
        float dt = min(max(rmag2 / RR - 1.0, 0.0) + base_dt, 2.0);
        //float dt = max(rmag / R / 10.0 - 1.0, 0.0) + base_dt;
        //float dt = base_dt;


        vec3 deflection = -1.5 * M * r_dir / rmag2;
        dir += deflection * dt;
        //if (i % 5 == 0)
        //    dir = normalize(dir);

        photonPos += dir * dt;
    }

    if (disk) {
        //FragColor = vec4(1.0f, 0.0f, 0.0f, 1.0f);
        FragColor = vec4(diskColor * diskAlpha + texture(skybox, dir).rgb * (1.0 - diskAlpha), 1.0);
    } else if (captured) {
        FragColor = vec4(0.0f);
    } else {
        FragColor = texture(skybox, dir);
    }
}
