#include <metal_stdlib>
using namespace metal;

// Constants for physical units and mathematical values (using SI units)
constant float gravitationalConstant = 6.67430e-11; // m^3 kg^-1 s^-2
constant float speedOfLight = 299792458.0;          // m/s
constant float solarMass = 1.98847e30;              // kg
constant float parsec = 3.0857e16;                  // m
constant float pi = 3.14159265358979323846;

// Structure to represent a binary black hole system
typedef struct {
    float mass1;        // Mass of the first black hole (in solar masses)
    float mass2;        // Mass of the second black hole (in solar masses)
    float distance;     // Distance to the system (in parsecs)
    float eccentricity; // Eccentricity of the orbit (0 for circular)
} BinaryBlackHole;

// Function to calculate the gravitational wave strain (h) at a given time
// Simplified model for gravitational wave calculation
float calculateStrain(float time, float frequency, float amplitude, BinaryBlackHole system) {
    // Convert units to SI
    float m1 = system.mass1 * solarMass;
    float m2 = system.mass2 * solarMass;
    float r = system.distance * parsec;

    // Total mass and reduced mass
    float totalMass = m1 + m2;
    float reducedMass = (m1 * m2) / totalMass;

    // Simplified model of the orbital frequency (valid for circular orbits)
    float orbitalFrequency = frequency / 2.0;  // GW frequency is twice the orbital frequency

    // Characteristic strain amplitude (h0)
    float h0 = (4.0 * gravitationalConstant * reducedMass) / (speedOfLight * speedOfLight * r) *
               pow((gravitationalConstant * totalMass * orbitalFrequency) / (speedOfLight * speedOfLight * speedOfLight), 2.0 / 3.0);

    // Calculate strain
    float strain = h0 * amplitude * sin(2.0 * pi * frequency * time);

    return strain;
}

// Compute shader to simulate gravitational waves from a binary black hole system
kernel void compute_gravitational_wave(
    device float *output [[buffer(0)]],
    constant float &time [[buffer(1)]],
    constant float &frequency [[buffer(2)]],
    constant float &amplitude [[buffer(3)]],
    constant BinaryBlackHole &system [[buffer(4)]],
    uint index [[thread_position_in_grid]]
) {
    const uint totalSamples = 1024;
    float timeStep = 1.0f / (frequency * 32.0f);
    float sampleTime = time + index * timeStep;
    float strain = calculateStrain(sampleTime, frequency, amplitude, system);
    output[index] = strain;
}

// Uniforms struct passed from the Swift code
struct Uniforms {
    float amplitude;
    float frequency;
    float time;
    float verticalScale;
    float horizontalScale;
};

vertex float4 vertex_main(constant float *strainData [[buffer(1)]],
                          constant Uniforms &uniforms [[buffer(2)]],
                          uint vid [[vertex_id]])
{
    // Map the vertex index to coordinates in a 3D grid
    float x = (float(vid) / 1024.0) * 2.0 - 1.0; // Normalize x from -1 to 1
    x *= uniforms.horizontalScale; // Apply horizontal scaling

    // Adjust vertical position based on strain and scale
    float y = strainData[vid] * uniforms.verticalScale;

    // Return the transformed vertex position
    return float4(x, y, 0.0, 1.0);
}
