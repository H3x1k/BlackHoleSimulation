#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <fstream>
#include <sstream>
#include <iostream>
#include <vector>

#include "stb_image.h"

const unsigned int WIDTH = 800;
const unsigned int HEIGHT = 800;

const float G = 1.0f; //6.7e-11f
const float c = 1.0f; //3.0e8f
const float M = 1.0f; //1.9e31f
const float R = 2.0f * G * M / c / c;

glm::vec3 cameraPos = glm::vec3(0.0f, 5.0f, 18.0f * R);
glm::vec3 cameraFront = glm::vec3(0.0f, 0.0f, -1.0f);
glm::vec3 cameraUp = glm::vec3(0.0f, 1.0f, 0.0f);
glm::vec3 cameraRight = glm::vec3(1.0f, 0.0f, 0.0f);

float yaw = 0.0f;
float pitch = 20.0f;
bool firstMouse = true;

float sensitivity = 0.1f;

glm::vec3 blackholePos = glm::vec3(0.0f, 0.0f, 0.0f);

void mouse_callback(GLFWwindow* window, double xpos, double ypos) {
    static float lastX = 800.0f / 2.0;
    static float lastY = 600.0f / 2.0;

    if (firstMouse) {
        lastX = xpos;
        lastY = ypos;
        firstMouse = false;
    }

    float xoffset = xpos - lastX;
    float yoffset = ypos - lastY;

    lastX = xpos;
    lastY = ypos;

    xoffset *= sensitivity;
    yoffset *= sensitivity;

    yaw += xoffset;
    pitch += yoffset;

    if (pitch > 89.0f) pitch = 89.0f;
    if (pitch < -89.0f) pitch = -89.0f;

    float sinyaw = sin(glm::radians(yaw));
    float cosyaw = cos(glm::radians(yaw));

    glm::vec3 frontdir;
    frontdir.x = sinyaw;
    frontdir.y = 0.0f;
    frontdir.z = -cosyaw;
    cameraFront = frontdir;

    glm::vec3 rightdir;
    rightdir.x = cosyaw;
    rightdir.y = 0.0f;
    rightdir.z = sinyaw;
    cameraRight = rightdir;
}
void processInput(GLFWwindow* window, float deltaTime) {
    const float cameraSpeed = 4.0f * deltaTime; // time-adjusted movement speed

    glm::vec3 movementVector = glm::vec3(0.0f, 0.0f, 0.0f);
    if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
        movementVector += cameraFront;
    if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
        movementVector -= cameraFront;
    if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
        movementVector -= cameraRight;
    if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
        movementVector += cameraRight;
    if (glfwGetKey(window, GLFW_KEY_E) == GLFW_PRESS)
        movementVector += cameraUp;
    if (glfwGetKey(window, GLFW_KEY_Q) == GLFW_PRESS)
        movementVector -= cameraUp;

    float mag = glm::length(movementVector);
    if (mag > 0)
        cameraPos += movementVector / mag * cameraSpeed * (glfwGetKey(window, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS ? 2.0f : 1.0f);
}

std::string loadShaderSource(const char* path) {
    std::ifstream file(path);
    if (!file) {
        std::cerr << "Failed to open shader file: " << path << '\n';
        return "";
    }
    std::stringstream ss;
    ss << file.rdbuf();
    return ss.str();
}
unsigned int compileShader(unsigned int type, const char* source) {
    unsigned int shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);

    int success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char infoLog[1024];
        glGetShaderInfoLog(shader, 1024, nullptr, infoLog);
        std::cerr << "Shader compilation failed ("
            << (type == GL_VERTEX_SHADER ? "Vertex" : "Fragment")
            << "):\n" << infoLog << '\n';
        glDeleteShader(shader);
        return 0;
    }

    return shader;
}
unsigned int createShaderProgram(const char* vertexPath, const char* fragmentPath) {
    std::string vCode = loadShaderSource(vertexPath);
    std::string fCode = loadShaderSource(fragmentPath);

    if (vCode.empty() || fCode.empty()) {
        std::cerr << "Shader source code is empty.\n";
        return 0;
    }

    unsigned int vs = compileShader(GL_VERTEX_SHADER, vCode.c_str());
    unsigned int fs = compileShader(GL_FRAGMENT_SHADER, fCode.c_str());

    if (vs == 0 || fs == 0) {
        std::cerr << "Shader compilation failed, program not created.\n";
        return 0;
    }

    unsigned int program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);

    int success;
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) {
        char infoLog[1024];
        glGetProgramInfoLog(program, 1024, nullptr, infoLog);
        std::cerr << "Shader program linking failed:\n" << infoLog << '\n';
        glDeleteProgram(program);
        program = 0;
    }

    glDeleteShader(vs);
    glDeleteShader(fs);
    return program;
}

unsigned int loadCubemap(std::vector<std::string> faces) {
    unsigned int textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_CUBE_MAP, textureID);

    int width, height, nrChannels;
    for (unsigned int i = 0; i < faces.size(); i++) {
        unsigned char* data = stbi_load(faces[i].c_str(), &width, &height, &nrChannels, 0);
        if (data) {
            glTexImage2D(
                GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
                0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, data
            );
            stbi_image_free(data);
        }
        else {
            std::cout << "Cubemap texture failed to load at path: " << faces[i] << std::endl;
            stbi_image_free(data);
        }
    }
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

    return textureID;
}

int main() {
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWmonitor* monitor = glfwGetPrimaryMonitor();
    const GLFWvidmode* mode = glfwGetVideoMode(monitor);

    GLFWwindow* window = glfwCreateWindow(mode->width, mode->height, "Black Hole Simulation", monitor, nullptr);
    //GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "Black Hole Simulation", nullptr, nullptr);
    glfwMakeContextCurrent(window);

    gladLoadGLLoader((GLADloadproc)glfwGetProcAddress);
    glEnable(GL_DEPTH_TEST);

    glfwSetCursorPosCallback(window, mouse_callback);
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);

    float quadVertices[] = {
        // positions   // texCoords
        -1.0f,  1.0f,  0.0f, 1.0f,  // top-left
        -1.0f, -1.0f,  0.0f, 0.0f,  // bottom-left
         1.0f, -1.0f,  1.0f, 0.0f,  // bottom-right

        -1.0f,  1.0f,  0.0f, 1.0f,  // top-left
         1.0f, -1.0f,  1.0f, 0.0f,  // bottom-right
         1.0f,  1.0f,  1.0f, 1.0f   // top-right
    };

    unsigned int quadVAO, quadVBO;
    glGenVertexArrays(1, &quadVAO);
    glGenBuffers(1, &quadVBO);
    glBindVertexArray(quadVAO);
    glBindBuffer(GL_ARRAY_BUFFER, quadVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0); // position
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float))); // texcoord
    glEnableVertexAttribArray(1);


    unsigned int shaderProgram = createShaderProgram(
        "../Shaders/vertex_shader.glsl", 
        "../Shaders/fragment_shader.glsl"//relativity_frag_shader.glsl
    );

    std::vector<std::string> faces = { // _2.png is 4096x4096, _.png is 512x512
        "../Skybox/right2.png",
        "../Skybox/left2.png",
        "../Skybox/top2.png",
        "../Skybox/bottom2.png",
        "../Skybox/front2.png",
        "../Skybox/back2.png"
    };
    unsigned int cubemapTexture = loadCubemap(faces);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapTexture);


    float lastFrame = 0.0f;
    float startTime = glfwGetTime();

    while (!glfwWindowShouldClose(window)) {
        if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
            glfwSetWindowShouldClose(window, true);

        float currentFrame = glfwGetTime();
        float deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;

        float time = glfwGetTime() - startTime;

        std::cout << 1 / deltaTime << std::endl;

        processInput(window, deltaTime);

        glClearColor(0.1f, 0.1f, 0.15f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glUseProgram(shaderProgram);
        

        glm::mat4 yawMat = glm::rotate(glm::mat4(1.0), glm::radians(yaw), glm::vec3(0.0, 1.0, 0.0));
        glm::mat4 pitchMat = glm::rotate(glm::mat4(1.0), glm::radians(pitch), cameraRight);

        glm::mat4 rotation = yawMat * pitchMat;
        glm::mat4 view = glm::inverse(rotation * glm::translate(glm::mat4(1.0f), -cameraPos));

        glm::mat4 projection = glm::perspective(glm::radians(90.0f), (float)WIDTH / HEIGHT, 0.1f, 100.0f);

        unsigned int viewLoc = glGetUniformLocation(shaderProgram, "view");
        unsigned int camPosLoc = glGetUniformLocation(shaderProgram, "cameraPos");
        glUniformMatrix4fv(viewLoc, 1, GL_FALSE, glm::value_ptr(view));
        glUniform3fv(camPosLoc, 1, glm::value_ptr(cameraPos));

        int width, height;
        glfwGetFramebufferSize(window, &width, &height);
        GLint resLoc = glGetUniformLocation(shaderProgram, "resolution");
        glUniform2f(resLoc, (float)width, (float)height);

        unsigned int bhPosLoc = glGetUniformLocation(shaderProgram, "bhPos");
        unsigned int MLoc = glGetUniformLocation(shaderProgram, "M");
        unsigned int RLoc = glGetUniformLocation(shaderProgram, "R");
        unsigned int timeLoc = glGetUniformLocation(shaderProgram, "time");

        glUniform3fv(bhPosLoc, 1, glm::value_ptr(blackholePos));
        glUniform1f(MLoc, M);
        glUniform1f(RLoc, R);
        glUniform1f(timeLoc, time);
        
        glBindVertexArray(quadVAO);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glDeleteVertexArrays(1, &quadVAO);
    glDeleteBuffers(1, &quadVBO);
    glfwTerminate();
    return 0;
}
