#version 330 core
precision mediump float;

uniform mat4 view;
uniform samplerCube skybox;
uniform vec2 resolution;
uniform vec3 cameraPos;
uniform vec3 bhPos;
uniform float M;
uniform float R;
uniform float time;

in vec2 coordPos;
out vec4 FragColor;

void main() {
    float aspectRatio = resolution.x / resolution.y;
    vec3 dir = normalize(vec3(coordPos.x * aspectRatio, coordPos.y, -0.8));
    dir = mat3(view) * dir;

    int MAX_ITER = 1000;
    float R_LIMIT = 35.0;
    bool captured = false;
    float base_dt = 0.1;
    
    vec3 photonPos = cameraPos;

    for (int i = 0; i < MAX_ITER; i++) {

        vec3 r = photonPos - bhPos;
        float rmag = length(r);

        //if (rmag < R) {
            //captured = true;
        //    break;
        //} else 
        if (rmag > R_LIMIT) {
            break;
        }

        vec3 r_dir = r / rmag;

        float rmag2 = rmag * rmag;
        float RR = 10.0 * R * R;
        //float rmag3 = rmag * rmag * rmag;

        float dt = clamp(rmag2 / RR * base_dt, base_dt, 1.0);
        //float dt = max(rmag2 / RR - 1.0, 0.0) + base_dt;
        //float dt = min(max(rmag2 / RR - 1.0, 0.0) + base_dt, 2.0);
        //float dt = max(rmag / R / 10.0 - 1.0, 0.0) + base_dt;

        vec3 deflection = -1.0 * M * r_dir / rmag2;
        dir += deflection * dt;
        dir = normalize(dir);
        photonPos += dir * dt;
    }


    if (captured) {
        FragColor = vec4(0.0f);
    } else {
        FragColor = texture(skybox, dir);
    }
}
