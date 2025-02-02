import SwiftUI

struct ContentView: View {
    // New parameters for a single-mass gravitational wave simulation:
    @State private var mass: Float = 30.0       // Mass of the object (in solar masses)
    @State private var waveSpeed: Float = 0.5     // Propagation speed of the gravitational wave
    @State private var frequency: Float = 10.0    // Frequency of the wave oscillation (Hz)
    @State private var energy: Float = 50.0       // Energy controlling the amplitude of the wave
    @State private var zoom: Float = 1.0          // Zoom factor to magnify the waveform

    var body: some View {
        VStack {
            Text("Gravitational Wave Simulator")
                .font(.largeTitle)
                .padding()

            // Use the updated SimulationView that accepts these parameters.
            SimulationView(mass: mass,
                           waveSpeed: waveSpeed,
                           frequency: frequency,
                           energy: energy,
                           zoom: zoom)
                .frame(width: 400, height: 400)
                .border(Color.black)

            VStack(alignment: .leading) {
                // Control for Mass
                Text("Mass (M☉): \(String(format: "%.1f", mass))")
                Slider(value: $mass, in: 5...100, step: 1)
                
                // Control for Wave Speed
                Text("Wave Speed: \(String(format: "%.2f", waveSpeed))")
                Slider(value: $waveSpeed, in: 0.1...2.0, step: 0.1)
                
                // Control for Frequency
                Text("Frequency (Hz): \(String(format: "%.1f", frequency))")
                Slider(value: $frequency, in: 1...100, step: 1)
                
                // Control for Energy
                Text("Energy: \(String(format: "%.1f", energy))")
                Slider(value: $energy, in: 0...100, step: 1)
                
                // Control for Zoom
                Text("Zoom: \(String(format: "%.1f", zoom))")
                Slider(value: $zoom, in: 0.5...10, step: 0.5)
            }
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
