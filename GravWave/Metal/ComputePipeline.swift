import Metal

class ComputePipeline {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var computePipeline: MTLComputePipelineState!
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        let library = device.makeDefaultLibrary()
        let kernelFunction = library?.makeFunction(name: "compute_gravitational_wave")
        do {
            computePipeline = try device.makeComputePipelineState(function: kernelFunction!)
        } catch {
            fatalError("Failed to create compute pipeline state: \(error)")
        }
    }
    
    func executeSimulation(time: Float, output: MTLBuffer, frequency: Float, energy: Float, waveSpeed: Float, system: BinaryBlackHole) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        // Set the compute pipeline state
        computeEncoder.setComputePipelineState(computePipeline)
        
        // Set the buffer for the output and other parameters
        computeEncoder.setBuffer(output, offset: 0, index: 0)
        
        // Set other parameters as bytes (uniforms, etc.)
        var mutableTime = time
        var mutableFrequency = frequency
        var mutableEnergy = energy
        var mutableWaveSpeed = waveSpeed
        computeEncoder.setBytes(&mutableTime, length: MemoryLayout<Float>.size, index: 1)
        computeEncoder.setBytes(&mutableFrequency, length: MemoryLayout<Float>.size, index: 2)
        computeEncoder.setBytes(&mutableEnergy, length: MemoryLayout<Float>.size, index: 3)
        computeEncoder.setBytes(&mutableWaveSpeed, length: MemoryLayout<Float>.size, index: 4)
        
        // Create a mutable copy of the system object and pass it as inout
        var mutableSystem = system
        computeEncoder.setBytes(&mutableSystem, length: MemoryLayout<BinaryBlackHole>.size, index: 5)
        
        // Dispatch the compute command
        let gridSize = MTLSize(width: 1024, height: 1, depth: 1)
        let threadGroupSize = MTLSize(width: computePipeline.threadExecutionWidth, height: 1, depth: 1)
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        
        // Commit the command buffer
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
