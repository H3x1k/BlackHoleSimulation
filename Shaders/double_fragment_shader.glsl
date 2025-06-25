#version 400 core
#extension GL_ARB_gpu_shader_fp64 : enable

precision highp float; // only affects float, not double

out vec4 FragColor;

uniform dmat4 view;
uniform samplerCube skybox;
uniform dvec2 resolution;

uniform dvec3 cameraPos;
uniform dvec3 bhPos;
uniform double M;
uniform double R;

uniform double time;

flat in dvec2 coordPos;

dvec2 fade(dvec2 t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

double grad(dvec2 hash, dvec2 p) {
    return dot(hash, p);
}

dvec2 random2(dvec2 st) {
    st = dvec2(dot(st, dvec2(127.1, 311.7)),
               dot(st, dvec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(st) * 43758.5453123);
}

double perlinNoise(dvec2 p) {
    dvec2 pi = floor(p);
    dvec2 pf = fract(p);

    dvec2 bl = random2(pi + dvec2(0.0, 0.0));
    dvec2 br = random2(pi + dvec2(1.0, 0.0));
    dvec2 tl = random2(pi + dvec2(0.0, 1.0));
    dvec2 tr = random2(pi + dvec2(1.0, 1.0));

    dvec2 f = fade(pf);

    double b = mix(grad(bl, pf - dvec2(0.0, 0.0)),
                   grad(br, pf - dvec2(1.0, 0.0)), f.x);
    double t = mix(grad(tl, pf - dvec2(0.0, 1.0)),
                   grad(tr, pf - dvec2(1.0, 1.0)), f.x);

    return 0.5 + 0.5 * mix(b, t, f.y);
}

double hash(dvec2 p) {
    p = fract(p * dvec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    double aspectRatio = resolution.x / resolution.y;
    dvec3 dir = normalize(dvec3(coordPos.x * aspectRatio, coordPos.y, -0.8));
    dir = dmat3(view) * dir;

    double r_min = 1.5 * R;
    double r_max = 10.0 * R;
    double height = 0.5;

    int MAX_ITER = 500;
    double R_LIMIT = 20.0 * R;
    bool captured = false;
    bool disk = false;
    dvec3 diskColor = dvec3(0.0);
    double diskAlpha = 0.0;

    double base_dt = 0.1;

    dvec3 photonPos = cameraPos;

    for (int i = 0; i < MAX_ITER; i++) {
        dvec3 r = photonPos - bhPos;
        double rmag = length(r);

        if (rmag < R) {
            captured = true;
            break;
        } else if (rmag > R_LIMIT) {
            break;
        }

        if (rmag > r_min && rmag < r_max && abs(r.y) < 0.5 * height) {
            double diskmag = length(r.xz);
            double theta = atan(r.z, r.x) + 5.0 * time / diskmag;
            dvec2 noiseCoord = dvec2(diskmag * 2.0, theta * 5.0);
            double noiseValue = perlinNoise(noiseCoord);

            double t = (rmag - r_min) / (r_max - r_min);
            double alpha = (1.0 - t) * ((1.0 - t) + noiseValue) * 0.5;
            if (alpha > diskAlpha) {
                diskColor = mix(dvec3(1.0, 1.0, 0.0), dvec3(1.0, 0.2, 0.0), t);
                diskAlpha = alpha;
                disk = true;
            }
        }

        dvec3 r_dir = r / rmag;

        double rmag2 = rmag * rmag;
        double RR = r_max * r_max;

        double dt = clamp(rmag2 / RR * base_dt, base_dt, 1.0);

        dvec3 deflection = -3.0 * M * r_dir / rmag2;
        dir += deflection * dt;

        photonPos += dir * dt;
    }

    vec3 finalColor;
    if (disk && captured) {
        finalColor = vec3(diskColor * diskAlpha);
    } else if (disk) {
        finalColor = vec3(diskColor * diskAlpha + texture(skybox, vec3(dir)).rgb * (1.0 - diskAlpha));
    } else if (captured) {
        finalColor = vec3(0.0);
    } else {
        finalColor = texture(skybox, vec3(dir)).rgb;
    }

    FragColor = vec4(finalColor, 1.0);
}
