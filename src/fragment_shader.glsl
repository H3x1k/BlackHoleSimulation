#version 330 core
precision mediump float;

out vec4 FragColor;

uniform mat4 view;
uniform samplerCube skybox;

uniform vec3 cameraPos;
uniform vec3 bhPos;
uniform float M;
uniform float R;

in vec2 coordPos;

void main() {
    vec3 dir = normalize(vec3(coordPos.x * 1.6, coordPos.y, -1.0));
    dir = mat3(view) * dir;
    
    float r_min = 3.0;
    float r_max = 5.0;
    float height = 0.2;

    int MAX_ITER = 600;
    float R_LIMIT = 20.0;
    bool captured = false;
    bool disk = false;

    float base_dt = 0.05;
    
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

        if (rmag > r_min && rmag < r_max && r.y > -0.5 * height && r.y < 0.5 * height)
        {
            disk = true;
            break;
        }  

        vec3 r_dir = r / rmag;

        float rmag2 = rmag * rmag;
        float RR = R * R;
        //float rmag3 = rmag * rmag * rmag;

        //float r_dot = dot(-r_dir, dir);
        //if (r_dot * R < -2.0) {
        //    break;
        //}

        //float dt = clamp(rmag2 / RR * base_dt, base_dt, 1.0);
        //float dt = max(rmag2 / RR - 1.0, 0.0) + base_dt;
        float dt = base_dt;


        vec3 deflection = -1.5 * M * r_dir / rmag2;
        dir += deflection * dt;
        //if (i % 5 == 0)
         //   dir = normalize(dir);

        photonPos += dir * dt;
    }

    if (disk) {
        FragColor = vec4(1.0f);
    } else if (captured) {
        FragColor = vec4(0.0f);
    } else {
        FragColor = texture(skybox, dir);
    }
}
