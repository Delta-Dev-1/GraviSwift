import SwiftUI
import MetalKit
import simd

/// A simulation view that renders a 3D gravitational wave ripple using a point cloud.
/// The ripple repeats over time as a sine‐based displacement is computed in the vertex shader.
struct SimulationView: NSViewRepresentable {
    // Simulation parameters.
    var mass: Float         // For future use (e.g. could modulate energy)
    var waveSpeed: Float    // Propagation speed of the wave
    var frequency: Float    // Oscillation frequency of the wave
    var energy: Float       // Controls the amplitude of the displacement
    var zoom: Float         // Used to adjust the view (zoom in/out)

    class Coordinator: NSObject, MTKViewDelegate {
        var pipeline: ComputePipeline
        var vertexBuffer: MTLBuffer!  // Buffer storing the 3D grid positions
        var renderPipelineState: MTLRenderPipelineState!
        
        // Uniforms passed to the vertex shader.
        struct Uniforms {
            var mvpMatrix: matrix_float4x4
            var time: Float
            var frequency: Float
            var energy: Float
            var waveSpeed: Float
        }
        var uniforms: Uniforms
        var uniformsBuffer: MTLBuffer!
        
        // Store simulation parameters.
        let mass: Float
        let waveSpeed: Float
        let frequency: Float
        let energy: Float
        let zoom: Float
        
        // Grid parameters.
        let gridDim: Int = 16  // 16×16×16 grid
        var totalVertices: Int { gridDim * gridDim * gridDim }
        
        init(pipeline: ComputePipeline, mass: Float, waveSpeed: Float, frequency: Float, energy: Float, zoom: Float) {
            self.pipeline = pipeline
            self.mass = mass
            self.waveSpeed = waveSpeed
            self.frequency = frequency
            self.energy = energy
            self.zoom = zoom
            
            // Initialize uniforms with default values.
            self.uniforms = Uniforms(mvpMatrix: matrix_identity_float4x4,
                                     time: 0.0,
                                     frequency: frequency,
                                     energy: energy,
                                     waveSpeed: waveSpeed)
            super.init()
            
            // Allocate and initialize the vertex buffer for the 3D grid.
            let bufferLength = totalVertices * MemoryLayout<SIMD3<Float>>.stride
            self.vertexBuffer = pipeline.device.makeBuffer(length: bufferLength, options: [])
            var positions = [SIMD3<Float>]()
            for z in 0..<gridDim {
                for y in 0..<gridDim {
                    for x in 0..<gridDim {
                        // Normalize coordinates to [-1, 1]
                        let xf = (Float(x) / Float(gridDim - 1)) * 2.0 - 1.0
                        let yf = (Float(y) / Float(gridDim - 1)) * 2.0 - 1.0
                        let zf = (Float(z) / Float(gridDim - 1)) * 2.0 - 1.0
                        positions.append(SIMD3<Float>(xf, yf, zf))
                    }
                }
            }
            memcpy(vertexBuffer.contents(), positions, bufferLength)
            
            // Allocate uniform buffer.
            self.uniformsBuffer = pipeline.device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
            
            setupMetal()
        }
        
        func setupMetal() {
            let library = pipeline.device.makeDefaultLibrary()
            guard let vertexFunction = library?.makeFunction(name: "vertex_main"),
                  let fragmentFunction = library?.makeFunction(name: "fragment_main") else {
                fatalError("Failed to load shader functions.")
            }
            
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            do {
                renderPipelineState = try pipeline.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            } catch {
                fatalError("Failed to create render pipeline state: \(error)")
            }
        }
        
        func draw(in view: MTKView) {
            let time = Float(CACurrentMediaTime())
            uniforms.time = time
            
            // Build a Model-View-Projection (MVP) matrix.
            let aspect = Float(view.drawableSize.width) / Float(view.drawableSize.height)
            let projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(45),
                                                                   aspectRatio: aspect,
                                                                   nearZ: 0.1,
                                                                   farZ: 100)
            // Create a view matrix: position the camera and apply zoom.
            let cameraDistance: Float = 3 / zoom
            let viewMatrix = matrix_look_at_right_hand(eye: SIMD3<Float>(0, 0, cameraDistance),
                                                         center: SIMD3<Float>(0, 0, 0),
                                                         up: SIMD3<Float>(0, 1, 0))
            let modelMatrix = matrix_identity_float4x4
            uniforms.mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
            
            // Update the uniform buffer.
            let uniformPointer = uniformsBuffer.contents()
            memcpy(uniformPointer, &uniforms, MemoryLayout<Uniforms>.stride)
            
            guard let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let commandBuffer = pipeline.commandQueue.makeCommandBuffer(),
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            else { return }
            
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
            // Draw the grid as a point cloud.
            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: totalVertices)
            
            renderEncoder.endEncoding()
            if let drawable = view.currentDrawable {
                commandBuffer.present(drawable)
            }
            commandBuffer.commit()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    }
    
    func makeCoordinator() -> Coordinator {
        let pipeline = ComputePipeline()
        return Coordinator(pipeline: pipeline,
                           mass: mass,
                           waveSpeed: waveSpeed,
                           frequency: frequency,
                           energy: energy,
                           zoom: zoom)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = context.coordinator.pipeline.device
        mtkView.delegate = context.coordinator
        mtkView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        mtkView.enableSetNeedsDisplay = true
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Update uniforms if simulation parameters change.
        context.coordinator.uniforms.frequency = frequency
        context.coordinator.uniforms.energy = energy
        context.coordinator.uniforms.waveSpeed = waveSpeed
        nsView.setNeedsDisplay(nsView.bounds)
    }
}

// MARK: - Helper Functions for Matrix Math

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio aspect: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tan(fovy * 0.5)
    let xs = ys / aspect
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4(columns: (
        SIMD4<Float>( xs,  0,   0,  0),
        SIMD4<Float>(  0, ys,   0,  0),
        SIMD4<Float>(  0,  0,  zs, -1),
        SIMD4<Float>(  0,  0, nearZ * zs,  0)
    ))
}

func matrix_look_at_right_hand(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> matrix_float4x4 {
    let z = simd_normalize(eye - center)
    let x = simd_normalize(simd_cross(up, z))
    let y = simd_cross(z, x)
    let trans = SIMD3<Float>(-simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye))
    return matrix_float4x4(columns: (
        SIMD4<Float>(x.x, y.x, z.x, 0),
        SIMD4<Float>(x.y, y.y, z.y, 0),
        SIMD4<Float>(x.z, y.z, z.z, 0),
        SIMD4<Float>(trans.x, trans.y, trans.z, 1)
    ))
}
