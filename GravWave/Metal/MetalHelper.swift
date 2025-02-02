//
//  MetalHelper.swift
//  GravWave
//
import Metal

// Utility functions for working with Metal
struct MetalHelper {
    // Creates a buffer with the given data
    static func createBuffer<T>(device: MTLDevice, data: [T]) -> MTLBuffer? {
        // Check if the data is empty to avoid creating an invalid buffer
        guard !data.isEmpty else { return nil }

        // Calculate the size of the buffer in bytes
        let size = data.count * MemoryLayout<T>.stride

        // Use the `UnsafeRawPointer` to the array's base address
        return data.withUnsafeBytes { rawBufferPointer in
            device.makeBuffer(bytes: rawBufferPointer.baseAddress!, length: size, options: [])
        }
    }
}
