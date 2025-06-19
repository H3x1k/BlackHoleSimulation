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
    // Initial direction (camera ray)
    vec3 dir = normalize(vec3(coordPos.x * 1.6, coordPos.y, -1.0));
    dir = mat3(view) * dir;

    // Compute impact parameter b = r0 * sin(theta)
    vec3 rel = cameraPos - bhPos;
    float r0 = length(rel);
    float b = length(cross(rel, dir)) / length(dir); // |r x v| / |v|

    float phi = 0.0;
    float u = 1.0 / r0;
    float dphi = 0.01;

    bool captured = false;

    for (int i = 0; i < 1000; i++) {
        float rhs = 1.0 / (b * b) - u * u + 2.0 * M * u * u * u;
        if (rhs < 0.0) break; // turn-around or escape

        float du = sqrt(rhs);
        u += du * dphi;
        phi += dphi;

        float r = 1.0 / u;

        if (r < R) {
            captured = true;
            break;
        }

        if (r > 20.0) break;
    }

    if (captured) {
        FragColor = vec4(0.0);
    } else {
        // Final deflected direction (back to cartesian)
        vec3 finalDir = vec3(cos(phi), 0.0, sin(phi));
        FragColor = texture(skybox, finalDir);
    }
}
