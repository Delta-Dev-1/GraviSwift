//
//  BinaryBlackHole.swift
//  GravWave
//
//  Created by Achyut on 02/02/2025.
//


import Foundation

// Structure to represent a binary black hole system
struct BinaryBlackHole {
    var mass1: Float        // Mass of the first black hole (in solar masses)
    var mass2: Float        // Mass of the second black hole (in solar masses)
    var distance: Float     // Distance to the system (in parsecs)
    var eccentricity: Float // Eccentricity of the orbit (0 for circular)
    
    // Initialize with default values (optional)
    init(mass1: Float = 30.0, mass2: Float = 30.0, distance: Float = 100.0, eccentricity: Float = 0.0) {
        self.mass1 = mass1
        self.mass2 = mass2
        self.distance = distance
        self.eccentricity = eccentricity
    }
}