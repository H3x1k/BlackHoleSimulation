#version 330 core
out vec4 FragColor;

uniform mat4 view;

uniform samplerCube skybox;

uniform vec3 cameraPos;
uniform vec3 bhPos;
uniform float M;
uniform float R;

in vec2 coordPos;

void main() {
    vec3 dir = normalize(vec3(coordPos.x, coordPos.y, -1.0));
    dir = mat3(view) * dir;
    
    float r_min = 3.0;
    float r_max = 5.0;
    float height = 0.1;

    int MAX_ITER = 600;
    float R_LIMIT = 100.0;
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

        float dt = base_dt * clamp(rmag / R, 0.1, 10.0);

        vec3 deflection = -1.5 * M * r / pow(rmag, 3.0);
        dir += deflection * dt;
        dir = normalize(dir);

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
